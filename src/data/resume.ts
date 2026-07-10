/**
 * Single source of truth for resume content.
 * Rendered as HTML by src/pages/resume.astro and as a PDF by src/pages/resume.pdf.ts.
 */

export interface ExperienceEntry {
  role: string;
  org: string;
  orgUrl?: string;
  location: string;
  dates: string;
  bullets?: string[];
  paragraph?: string;
  /** Muted timeline dot on the HTML page (used for the career break). */
  muted?: boolean;
}

export interface EarlyCareerEntry {
  title: string;
  description: string;
}

export const resume = {
  name: 'Jordan Hornblow',
  tagline:
    'Principal Engineer at Contented | Distributed Systems & Cloud Architecture | Platform Engineering & Applied AI',
  location: 'Te Waipounamu, Aotearoa | New Zealand',
  email: 'jordan@jch254.com',
  website: 'https://jch254.com',
  linkedin: 'https://linkedin.com/in/jch254',
  github: 'https://github.com/jch254',

  summary: [
    'Principal Engineer at Contented with 15+ years of experience building and scaling platforms across fintech, hospitality, legal tech, and applied AI (Xero, me&u, LawVu, Contented).',
    'My work spans product engineering, architecture, platform reliability, and applied AI. The role sits between hands-on delivery and technical direction: scaling product architecture, strengthening AI workflows, improving reliability, and helping teams build systems that stay simple to operate as a company grows.',
    'I care about practical engineering for real customer environments: clear architecture, secure workflows, tenant-aware systems, and AI that earns its place in the product rather than adding unnecessary complexity.',
  ],

  skills: [
    { label: 'Domain Expertise', items: 'API Design, Microservices, SaaS Scaling, Automation' },
    { label: 'Core Technologies', items: 'TypeScript, Node.js, React, Python, AWS, NestJS' },
    { label: 'Cloud & Infrastructure', items: 'AWS, Azure, Terraform, Docker' },
    { label: 'AI/ML', items: 'Claude, OpenAI ChatGPT, Azure AI, Prompt Engineering' },
    { label: 'Architecture', items: 'Microservices, Event-Driven, API Design (REST/GraphQL)' },
  ],

  experience: [
    {
      role: 'Principal Engineer',
      org: 'Contented',
      orgUrl: 'https://www.contented.app/',
      location: 'Christchurch, New Zealand',
      dates: 'Jun 2026 – Present',
      bullets: [
        'Working across product engineering, architecture, platform reliability, and applied AI.',
        'Scaling the product architecture, strengthening AI workflows, and improving reliability as the company grows.',
        'Focused on practical engineering for real customer environments: clear architecture, secure workflows, and tenant-aware systems.',
        'Bridging hands-on delivery and technical direction; helping the team build systems that stay simple to operate at scale.',
      ],
    },
    {
      role: 'Senior Software Engineer L2',
      org: 'LawVu',
      orgUrl: 'https://lawvu.com',
      location: 'Remote, New Zealand',
      dates: 'Apr 2024 – Aug 2025',
      bullets: [
        'Built contract management workflows. Improved customer onboarding speed.',
        'Built C# backend for approval workflows. Led migration from legacy systems.',
        'Built a Python/OpenAI spreadsheet transformation service to automate onboarding data prep.',
        'Built a PDF parsing pipeline (Python + Azure AI) that processed 10k+ legacy contracts. Beat commercial tools like Zuva on accuracy and speed.',
      ],
    },
    {
      role: 'Career Break',
      org: '',
      location: 'Austin, TX',
      dates: 'Mar 2023 – Apr 2024',
      paragraph:
        'Took time away from full-time engineering to focus on health. Used this period to reset and prepare for relocation back to NZ.',
      muted: true,
    },
    {
      role: 'Head of Integration Engineering (Principal Engineer)',
      org: 'me&u (FKA Mr Yum)',
      orgUrl: 'https://www.meandu.com/',
      location: 'Melbourne / Austin, TX',
      dates: 'Apr 2020 – Mar 2023',
      bullets: [
        'Early engineer. Built and scaled third-party API integrations from 5 to 50+ partners in 18 months.',
        'Led integrations team of 6. Mentored 3 to promotions. Set development practices adopted across the org.',
        'Relocated to Austin, TX to lead US partner integrations and expand into North America.',
        'Broke the me&u monolith into focused services.',
        'Stack: TypeScript, React, NestJS, GraphQL, Terraform, AWS.',
        "Part of Australia's third-largest Series A ($65M USD, 2021).",
      ],
    },
    {
      role: 'Senior Full Stack Developer',
      org: 'APositive',
      orgUrl: 'https://www.apositive.com.au/',
      location: 'Melbourne, Australia',
      dates: 'Dec 2016 – Jul 2020',
      bullets: [
        'Built and maintained fintech products with React, Node.js, Terraform, and AWS.',
        'Designed and shipped APay, a workforce finance product (think Afterpay for recruiters).',
        'Wrote all infrastructure automation and handled cloud migration.',
      ],
    },
    {
      role: 'Developer / Senior Developer',
      org: 'Xero',
      orgUrl: 'https://www.xero.com',
      location: 'Melbourne, Australia',
      dates: 'May 2014 – Dec 2016',
      bullets: [
        'Shipped features across multiple teams: fixed assets, quotes, 2FA, provisioning.',
        'Core developer on Xero TaxTouch (iOS). Covered design, development, release, and prod support.',
        'Worked with teams across time zones. Full end-to-end mobile delivery.',
        'Promoted to senior developer, Oct 2016.',
      ],
    },
    {
      role: 'Software Engineer',
      org: 'Telogis / Verizon Connect',
      orgUrl: 'https://www.verizonconnect.com/au/v/fleet/gpsfleet/gps-fleet-tracking-software',
      location: 'Christchurch, NZ',
      dates: 'Mar 2012 – Mar 2014',
      bullets: [
        'Built backend services for Telogis Fleet SaaS with .NET, JavaScript, and PostgreSQL.',
        'Rebuilt the Fleet UI in Ext JS. Created reusable components picked up by other products.',
        'Developer exchange in Austin, TX (2013). Worked on parsing raw UDP GPS/diagnostic packets into standardized formats.',
      ],
    },
  ] satisfies ExperienceEntry[],

  earlyCareer: [
    {
      title: 'Founder / Software Engineer, Kiwi Development (2011–2014)',
      description:
        'Founded Kiwi Development. Accepted into Microsoft BizSpark. Delivered client projects in .NET, Ruby on Rails, and JavaScript. Managed Windows/SQL Server infrastructure. Maintained Inzone Experience kiosks across NZ.',
    },
    {
      title: 'Tutor, University of Canterbury (2011)',
      description:
        'Taught Python & CS fundamentals. Led classes of 50. Supported Pacific students via PASS programme.',
    },
    {
      title: 'Research Intern, HITLab NZ (2010–2011)',
      description:
        'Summer Scholarship recipient. Researched mobile AR for navigation. Ran experiments. Learned Android/AR systems.',
    },
  ] satisfies EarlyCareerEntry[],

  education: {
    degree: 'BSc (Computer Science)',
    org: 'University of Canterbury',
    location: 'Christchurch, NZ',
    dates: '2009–2011',
    bullets: [
      'Completed projects in Java, C, C++, Python, and Android.',
      'Covered the full development lifecycle: requirements, design, implementation, testing.',
    ],
  },

  achievements: [
    'University of Canterbury Summer Scholarship (2010–2011)',
    'Golden Key International Honour Society (2009–present)',
    'College of Engineering Computer Science Scholarship (2009)',
    'NCEA Levels 1–3 & NZ University Entrance',
  ],

  personal:
    'Avid vinyl collector (800+ records), musician/producer aspiring to merge music + software, open-source contributor, photographer, and advocate for suicide awareness after losing two close friends.',
};
