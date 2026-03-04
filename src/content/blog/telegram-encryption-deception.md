---
title: "Telegram's Encryption Deception"
description: "As mentioned by many news sources around the globe - Telegram will better cooperate with law enforcement agencies and hand over user data."
date: 2024-09-15
tags: ["security", "privacy", "encryption", "tech"]
draft: false
---

As mentioned by many news sources around the globe - Telegram will better cooperate with law enforcement agencies and hand over the IP addresses and phone numbers of users in response to "valid requests", in a major policy change from the encrypted messaging platform just weeks after the arrest of its founder.

A surprising fact that many of Telegram's nearly one billion users likely do not realize is that while many of Telegram's rivals have adopted end-to-end/client-to-client encryption by default, Telegram has not. Unless users manually set up a "Secret Chat" within the app with each and every specific contact they require end-to-end/client-to-client encrypted conversations with, the company is likely able to access/read messages being sent on the platform stored in their database servers (Telegram is a cloud-based service after all). There are often controls around production database access at technology companies depending on company policies, however if this is not well enforced as is often the case, employees may have full production read/write access to production data.

I imagine when those law enforcement requests start flowing in, Telegram are gonna be busy... As illicit Telegram groups clear/reduce their presence on the platform by deleting chats and media, it's possible this is pointless. Many tech companies keep database backups and soft delete data so it's not actually deleted from the database servers (just a deleted date column is set in the related database table/s).

## Direct from Telegram's FAQ

### Q: How are secret chats different?

Secret chats are meant for people who want more secrecy than the average fella. All messages in secret chats use end-to-end encryption. This means only you and the recipient can read those messages — nobody else can decipher them, including us here at Telegram. On top of this, Messages cannot be forwarded from secret chats. And when you delete messages on your side of the conversation, the app on the other side of the secret chat will be ordered to delete them as well.

You can order your messages, photos, videos and files to self-destruct in a set amount of time after they have been read or opened by the recipient. The message will then disappear from both your and your friend's devices.

All secret chats in Telegram are device-specific and are not part of the Telegram cloud. This means you can only access messages in a secret chat from their device of origin. They are safe for as long as your device is safe in your pocket.

### Q: Why not just make all chats 'secret'?

All Telegram messages are always securely encrypted. Messages in Secret Chats use *client-client* encryption, while Cloud Chats use *client-server/server-client* encryption and are stored in the Telegram Cloud. This enables your cloud messages to be both secure and immediately accessible from any of your devices - even if you lose your device altogether.

The problem of restoring access to your chat history on a newly connected device (e.g. when you lose your phone) does not have an elegant solution in the end-to-end encryption paradigm. At the same time, reliable backups are an essential feature for any mass-market messenger. To solve this problem, some applications (like WhatsApp and Viber) allow decryptable backups that put their users' privacy at risk - even if they do not enable backups themselves. Other apps ignore the need for backups altogether and leave their users vulnerable to data loss.

We opted for a third approach by offering two distinct types of chats. Telegram disables default system backups and provides all users with an integrated security-focused backup solution in the form of Cloud Chats. Meanwhile, the separate entity of Secret Chats gives you full control over the data you do not want to be stored.

### Q: Can Telegram protect me against everything?

Telegram can help when it comes to data transfer and secure communication. This means that all data (including media and files) that you send and receive via Telegram cannot be deciphered when intercepted by your Internet service provider, owners of Wi-Fi routers you connect to, or other third parties.

But please remember that we cannot protect you from your own mother if she takes your unlocked phone without a passcode. Or from your IT-department if they access your computer at work. Or from any other people that get physical or root access to your phones or computers running Telegram.

If you have reasons to worry about your personal security, we strongly recommend using only Secret Chats in official or at least verifiable open-source apps for sensitive information, preferably with a self-destruct timer. We also recommend enabling 2-Step Verification and setting up a strong passcode to lock your app. You will find both options in Settings → Privacy and Security.

## Telegram's Privacy Policy

### 3.3.1 Cloud Chats

Telegram is a cloud service. We store messages, photos, videos and documents from your cloud chats on our servers so that you can access your data from any of your devices anytime without having to rely on third-party backups.

### 3.3.2 Secret Chats

Secret chats use end-to-end encryption. This means that all data is encrypted with a key that only you and the recipient know. There is no way for us or anybody else without direct access to your device to learn what content is being sent in those messages. We do not store your secret chat messages on our servers. We also do not keep any logs for messages in secret chats, so after a short period of time we no longer know who or when you messaged via secret chats. For the same reasons secret chats are not available in the cloud — you can only access those messages from the device they were sent to or from.

Watch my YouTube overview and switch to Signal ASAP - [https://signal.org](https://signal.org) - let the Signal exodus begin!

## Further reading

- [Telegram General FAQ for the Technically Inclined](https://core.telegram.org/techfaq)
- [Telegram Encryption FAQ for the Technically Inclined](https://core.telegram.org/api/end-to-end)
- [MTProto Mobile Protocol](https://core.telegram.org/mtproto)
- [Pavel Durov's post on why Telegram isn't End-to-End Encrypted by Default](https://telegra.ph/Why-Isnt-Telegram-End-to-End-Encrypted-by-Default-08-14)
