---
title: "Getting GPT-6 Astra Working in Zed Through Amazon Bedrock"
description: "Zed showed one vague error banner. Underneath it were four separate problems: a missing auth block, cross-region inference profile IDs, a model that does not exist on Bedrock Mantle and a temperature field the model refuses. The fix was a LiteLLM shim."
date: 2026-09-22
tags: ["ai", "aws", "developer tools"]
draft: true
---

I wanted to use GPT-6 Astra in Zed's agent panel, through the Bedrock account I already had. Zed lists Bedrock as a provider. Bedrock lists Astra as a model. Should have been ten minutes.

```
Amazon Bedrock's API returned an unexpected error. If the problem persists, try switching models or restarting Zed.
```

It was an hour. The banner never changed, but the error behind it changed four times.

If you only want the fix: Astra rejects the `temperature` and `top_p` fields that Zed sends on every request, so Zed's native Bedrock provider cannot drive it. Put a LiteLLM proxy in front, drop those two parameters explicitly and point Zed's `openai_compatible` provider at the proxy. Config is at the bottom. The rest of this is how I got there, because each wrong turn was a real thing worth knowing.

## Read the log, not the banner

The banner is Zed catching an exception and printing a generic string. The real error is in `~/Library/Logs/Zed/Zed.log`.

```bash
tail -f ~/Library/Logs/Zed/Zed.log
```

That one command would have saved me twenty minutes of guessing about IAM and regions. The first real error was this:

```
ERROR [agent::thread] Turn execution failed: The model 'openai.gpt-6-astra' does not exist
```

Credentials were loading fine. The log showed `aws_config` reading the profile on every attempt. The model was the problem.

## Zed needs the auth block even when credentials work

My settings had a `language_models.bedrock` section with a list of models and nothing else. No `authentication_method`, no `region`, no `profile`. Zed was falling back to whatever the default profile and shell environment gave it, which was not the profile I was testing on the command line.

```json
"language_models": {
  "bedrock": {
    "authentication_method": "named_profile",
    "region": "us-east-1",
    "profile": "bedrock",
    "available_models": [ ... ]
  }
}
```

Adding that did not fix the error, but it did make the rest of the debugging honest. Without it, Zed was picking up whatever the shell environment gave it, which is not the same thing as the profile you think you are testing on the command line.

## Bare model IDs are not invokable

Bedrock's model catalogue lists `openai.gpt-6-astra`. That is the foundation model ID. It is not what you invoke.

```bash
aws bedrock-runtime invoke-model --model-id openai.gpt-6-astra ...
```

```
ValidationException: Invocation of model ID openai.gpt-6-astra with on-demand throughput isn't supported. Retry your request with the ID or ARN of an inference profile that contains this model.
```

Every recent model on Bedrock is invoke-only through a cross-region inference profile. The profile IDs carry a geography prefix.

```bash
aws bedrock list-inference-profiles --region us-east-1 \
  --query 'inferenceProfileSummaries[?contains(inferenceProfileId,`astra`)].inferenceProfileId' \
  --output text
```

```
us.openai.gpt-6-astra
global.openai.gpt-6-astra
```

With `us.openai.gpt-6-astra`, both `converse` and `invoke-model` returned text from the command line. So the model worked. Zed still said it did not exist.

## Two Bedrock endpoints, two naming rules

This is the part I did not know going in, and it is the part most likely to catch someone else.

Bedrock has two inference endpoints now. `bedrock-runtime` serves Converse and InvokeModel. `bedrock-mantle` is a separate host, `bedrock-mantle.{region}.api.aws`, serving OpenAI-compatible Chat Completions and Responses APIs. Some models are only on one of them.

Zed has two config keys to match. `available_models` goes through Converse. `mantle_available_models` goes through Mantle, and its entries require a `protocol` field that only accepts `chat_completions` or `responses`.

I had Astra under `mantle_available_models`, because that is where the OpenAI models seemed like they should live. Two things were wrong with that.

Mantle takes model IDs verbatim with no prefix. The `us.` I had just learned to add is a Converse concept. So `us.openai.gpt-6-astra` was never going to resolve on Mantle, and the bare ID would have failed for the second reason.

Astra is not on Mantle in us-east-1 at all. The AWS CLI does not have a `bedrock-mantle` command yet, even on the current version, so I hit the endpoint directly with SigV4.

```bash
curl -s "https://bedrock-mantle.us-east-1.api.aws/v1/models" \
  --aws-sigv4 "aws:amz:us-east-1:bedrock" \
  --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY"
```

The list had `openai.gpt-5.6-sol`, `openai.gpt-5.6-terra`, `openai.gpt-5.6-luna`, `openai.gpt-5.5`, `openai.gpt-5.4` and the open-weight `gpt-oss` models. No Astra. Whatever combination of name and protocol I put in the Mantle block, the answer was always going to be "does not exist", and the error message was literally correct.

The same listing had a side note worth recording. `anthropic.claude-fable-5` showed as unavailable, with the reason that the model is not offered under the account's data retention mode. That is an account setting, not a config one, and it is a separate reason a model can refuse you.

## Moving to Converse surfaced the next two errors

Astra went into `available_models` with the `us.` prefix. The model resolved. Two new errors, in quick succession.

```
The toolConfig field must be defined when using toolUse and toolResult content blocks.
```

My `available_models` entry did not declare `supports_tools`, so Zed treated the model as toolless. But the thread I was retrying in already had tool calls in its history from earlier attempts, and Converse rejects tool blocks without a tool config. Adding `"supports_tools": true` and starting a fresh thread cleared it. Retrying an old thread replays its history, which is worth remembering whenever you change a model's capabilities.

Then the one that ended the native route.

```
This model doesn't support the temperature field. Remove temperature and try again.
```

Zed sends `temperature` on every Converse request. There is no setting to turn it off. `model_parameters` lets you set a value, not omit the field. Astra rejects it outright. It turned out to reject `top_p` the same way, which Zed also sends.

That is a Zed bug, and a narrow one. There are already GitHub discussions asking for the newer OpenAI models on Bedrock to be supported, so it will presumably get fixed. I did not want to wait.

## The shim

LiteLLM runs as an OpenAI-compatible proxy and can talk to Bedrock Converse behind it. Zed has an `openai_compatible` provider. Put one in front of the other and Zed never touches Bedrock directly.

```yaml
model_list:
  - model_name: astra
    litellm_params:
      model: bedrock/us.openai.gpt-6-astra
      aws_profile_name: bedrock
      aws_region_name: us-east-1
      additional_drop_params: ["temperature", "top_p"]
litellm_settings:
  drop_params: true
```

`drop_params: true` on its own was not enough. LiteLLM only drops parameters it already believes a provider does not support, and its Bedrock mapping treats `temperature` as supported, so it passed straight through. `additional_drop_params` names them explicitly.

I verified the proxy before touching editor config, with requests that deliberately carried `temperature`. Plain completion, streaming and a tool call all came back 200. Then the Zed side:

```json
"openai_compatible": {
  "litellm": {
    "api_url": "http://localhost:4000/v1",
    "available_models": [
      {
        "name": "astra",
        "display_name": "GPT-6 Astra (LiteLLM)",
        "max_tokens": 1050000,
        "supports_tools": true
      }
    ]
  }
}
```

Zed asks for an API key for the provider. The proxy has no auth, so any non-empty string works.

The proxy runs under launchd with `KeepAlive` so it survives crashes and starts at login. I tested that with `kill -9` rather than trusting the plist. Logs go to `~/Library/Logs/litellm/`. The AWS profile it uses has long-term keys rather than an MFA session, which is the only reason a background agent is viable. A session-based profile would expire mid-afternoon and the proxy would fail with no obvious cause.

One environment gotcha: my shell had `AWS_REGION` set, and `aws configure list` showed the region coming from the environment rather than the profile. A launchd agent gets a minimal environment and would not see it. Setting `aws_region_name` explicitly in the LiteLLM config is what made that not matter.

## Two things that were not about Bedrock

While setting up the shim, the agent fetched `https://pypi.org/pypi/litellm/json` to find the current version. That endpoint returns the full release history for every version ever published. The request failed with a prompt of 1.45 million tokens. If an agent's context suddenly explodes and the files in play are small, look at what it fetched.

And the boring one. Zed's settings file is where extension tokens live, in plaintext, and it is exactly the file you paste into a chat when asking for help. I did that before noticing. Rotate anything that has been through a chat window, and keep secrets out of the file in the first place where the extension allows it.

## The actual end state

- Astra runs through LiteLLM on localhost, driven by Zed's `openai_compatible` provider
- The proxy drops `temperature` and `top_p` explicitly with `additional_drop_params`
- launchd keeps it alive, logging to `~/Library/Logs/litellm/`
- Claude models stay on Zed's native Bedrock provider under `available_models`, with `us.` prefixed inference profile IDs
- `mantle_available_models` is gone

## What I learned

Read the log first. Zed's banner told me nothing four times in a row. The log named the exact problem every time.

Bedrock model IDs are not one thing. Foundation model IDs are what the catalogue shows. Inference profile IDs, with `us.` or `global.` prefixes, are what Converse and InvokeModel accept. Mantle takes bare IDs and serves a different set of models. Check which endpoint has your model before you configure anything.

An error can be literally true and still misleading. "The model does not exist" was correct every time. It was the endpoint I was asking that was wrong.

When a client sends a field a model refuses and gives you no way to stop it, a translating proxy is a fair answer. It is another process to run, but it is also the same adapter pattern I would use in application code: the thing that talks to the provider is the thing that knows the provider's quirks.

The whole reason I wanted Astra in the editor was to build a voice agent side project where the LLM sits behind an adapter so the model can be swapped by config. The evening turned into a live demonstration of why.
