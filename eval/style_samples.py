"""
style_samples.py — Test samples for Concise, Casual, and Professional modes.

Unlike grammar correction, style transformation has no standard benchmark dataset.
These are hand-curated samples with 1-2 reference outputs each, covering the range
of inputs ProseKit will encounter: chat messages, emails, technical writing, etc.

Each sample has:
  - source: the input text
  - references: 1-2 acceptable reference transformations
  - preserve: key terms/facts that MUST appear in the output (meaning check)
"""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONCISE MODE — should shorten text while preserving core meaning
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CONCISE_SAMPLES = [
    {
        "source": "I just wanted to reach out to you to let you know that I think we should probably schedule a meeting at some point in the near future to discuss the project.",
        "references": [
            "Let's schedule a meeting to discuss the project.",
            "We should meet soon to discuss the project.",
        ],
        "preserve": ["meeting", "project"],
    },
    {
        "source": "Due to the fact that the weather conditions were extremely unfavorable, we made the decision to postpone the outdoor event until a later date.",
        "references": [
            "We postponed the outdoor event due to bad weather.",
            "Bad weather forced us to postpone the outdoor event.",
        ],
        "preserve": ["postpone", "outdoor event", "weather"],
    },
    {
        "source": "In my personal opinion, I believe that the new software update is going to be very beneficial for all of the users who are currently using the platform on a daily basis.",
        "references": [
            "The new software update will benefit daily users.",
            "I think the new update will help daily users.",
        ],
        "preserve": ["software update", "users"],
    },
    {
        "source": "At this point in time, we are currently in the process of evaluating and assessing all of the various different options that are available to us.",
        "references": [
            "We're evaluating our options.",
            "We're currently assessing the available options.",
        ],
        "preserve": ["evaluating", "options"],
    },
    {
        "source": "The reason why the project was delayed was because the team did not have enough resources to complete it on time.",
        "references": [
            "The project was delayed due to insufficient resources.",
            "Lack of resources delayed the project.",
        ],
        "preserve": ["project", "delayed", "resources"],
    },
    {
        "source": "I would like to take this opportunity to express my sincere gratitude for the help and assistance that you provided to me during the course of last week.",
        "references": [
            "Thank you for your help last week.",
            "Thanks for helping me last week.",
        ],
        "preserve": ["thank", "help", "last week"],
    },
    {
        "source": "Please do not hesitate to reach out to me if you have any questions or concerns regarding any of the matters that we discussed during our meeting yesterday.",
        "references": [
            "Let me know if you have questions about yesterday's meeting.",
            "Feel free to reach out with questions about what we discussed yesterday.",
        ],
        "preserve": ["questions", "meeting", "yesterday"],
    },
    {
        "source": "It is important to note that the deadline for the submission of all required documents is Friday, March 15th, and no extensions will be granted under any circumstances.",
        "references": [
            "All documents are due Friday, March 15th. No extensions.",
            "The deadline is Friday, March 15th — no extensions.",
        ],
        "preserve": ["deadline", "Friday", "March 15th", "no extensions"],
    },
    {
        "source": "The CEO made the announcement that the company would be implementing a new policy that would require all employees to return to the office on a full-time basis starting next month.",
        "references": [
            "The CEO announced a full-time return-to-office policy starting next month.",
            "Starting next month, all employees must return to the office full-time per the CEO.",
        ],
        "preserve": ["CEO", "return", "office", "next month"],
    },
    {
        "source": "Despite the fact that the initial prototype had a number of issues and problems, the engineering team was ultimately able to resolve them and deliver a working product.",
        "references": [
            "Despite initial prototype issues, the engineering team delivered a working product.",
            "The engineering team fixed the prototype's issues and delivered a working product.",
        ],
        "preserve": ["prototype", "engineering team", "working product"],
    },
    # Short texts — should have minimal changes
    {
        "source": "Let's meet tomorrow at 3pm.",
        "references": [
            "Let's meet tomorrow at 3pm.",
        ],
        "preserve": ["meet", "tomorrow", "3pm"],
    },
    {
        "source": "The API returns JSON.",
        "references": [
            "The API returns JSON.",
        ],
        "preserve": ["API", "JSON"],
    },
    # Chat messages
    {
        "source": "Hey, I just wanted to let you know that I'm going to be running a little bit late to the thing tonight, probably like 15 minutes or so, sorry about that!",
        "references": [
            "Hey, running about 15 minutes late tonight, sorry!",
            "I'll be ~15 min late tonight, sorry!",
        ],
        "preserve": ["late", "15 minutes", "tonight"],
    },
    {
        "source": "So basically what happened was that the server went down at around 2am and then it took the on-call engineer approximately three hours to get everything back up and running again.",
        "references": [
            "The server went down around 2am and took the on-call engineer ~3 hours to restore.",
            "Server went down at 2am; on-call took about 3 hours to fix it.",
        ],
        "preserve": ["server", "2am", "three hours", "on-call"],
    },
    {
        "source": "I think that it would be a really great idea if we could somehow find a way to automate this particular process so that we don't have to keep doing it manually every single time.",
        "references": [
            "We should automate this process to avoid doing it manually.",
            "Let's automate this — doing it manually every time is inefficient.",
        ],
        "preserve": ["automate", "process", "manually"],
    },
]

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CASUAL MODE — should make text sound friendly, conversational, natural
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CASUAL_SAMPLES = [
    {
        "source": "I would like to inform you that the meeting has been rescheduled to Thursday at 2:00 PM.",
        "references": [
            "Hey, just a heads up — the meeting's been moved to Thursday at 2 PM.",
            "FYI, the meeting got pushed to Thursday at 2 PM.",
        ],
        "preserve": ["meeting", "Thursday", "2"],
    },
    {
        "source": "We regret to inform you that your request has been denied due to insufficient documentation.",
        "references": [
            "Sorry, your request was denied — looks like some documents were missing.",
            "Unfortunately, your request got denied because of missing documentation.",
        ],
        "preserve": ["request", "denied", "documentation"],
    },
    {
        "source": "Please ensure that all deliverables are submitted prior to the established deadline.",
        "references": [
            "Make sure to get everything in before the deadline!",
            "Don't forget to submit everything before the deadline.",
        ],
        "preserve": ["submit", "deadline"],
    },
    {
        "source": "The quarterly financial results exceeded expectations, with revenue increasing by 15% year-over-year.",
        "references": [
            "Great news — quarterly revenue is up 15% compared to last year!",
            "The quarterly numbers came in strong, with revenue up 15% year-over-year.",
        ],
        "preserve": ["quarterly", "revenue", "15%"],
    },
    {
        "source": "It has come to my attention that several team members have not completed the mandatory training modules.",
        "references": [
            "Hey, looks like some folks on the team still haven't done the required training.",
            "Just noticed a few team members haven't finished the mandatory training yet.",
        ],
        "preserve": ["team members", "training"],
    },
    {
        "source": "I am writing to express my interest in the software engineering position that was recently posted on your website.",
        "references": [
            "I'm interested in the software engineering role you posted on your site!",
            "I saw the software engineering job on your website and I'd love to apply.",
        ],
        "preserve": ["software engineering", "position", "website"],
    },
    {
        "source": "Pursuant to our previous discussion, I have attached the revised proposal for your review and consideration.",
        "references": [
            "As we talked about, here's the updated proposal — let me know what you think!",
            "Following up on our chat, I've attached the revised proposal. Take a look!",
        ],
        "preserve": ["proposal", "revised"],
    },
    {
        "source": "The implementation of the new system will commence on Monday and is expected to be completed within a two-week timeframe.",
        "references": [
            "We're kicking off the new system on Monday — should take about two weeks.",
            "The new system rollout starts Monday and should be done in about two weeks.",
        ],
        "preserve": ["new system", "Monday", "two weeks"],
    },
    # Already casual — should be mostly unchanged
    {
        "source": "Hey, wanna grab lunch tomorrow?",
        "references": [
            "Hey, wanna grab lunch tomorrow?",
            "Hey, want to grab lunch tomorrow?",
        ],
        "preserve": ["lunch", "tomorrow"],
    },
    {
        "source": "That movie was awesome, you should totally check it out!",
        "references": [
            "That movie was awesome, you should totally check it out!",
        ],
        "preserve": ["movie", "awesome"],
    },
    # Technical text
    {
        "source": "The function accepts an integer parameter and returns a boolean value indicating whether the input is a prime number.",
        "references": [
            "This function takes an integer and returns whether it's prime.",
            "You pass it an integer and it tells you if it's prime or not.",
        ],
        "preserve": ["integer", "prime"],
    },
    # Formal email
    {
        "source": "Dear Mr. Johnson, I am writing to follow up on the invoice that was sent on January 15th. As of today, payment has not been received. Could you please provide an update on the expected payment date?",
        "references": [
            "Hi Mr. Johnson, just following up on the invoice from January 15th — we haven't received payment yet. Any idea when it'll go through?",
            "Hey Mr. Johnson, quick follow-up on the Jan 15th invoice. We haven't gotten payment yet — do you know when to expect it?",
        ],
        "preserve": ["Johnson", "invoice", "January 15th", "payment"],
    },
    {
        "source": "All personnel are required to vacate the premises by 6:00 PM due to scheduled maintenance of the HVAC system.",
        "references": [
            "Everyone needs to leave the building by 6 PM — they're doing HVAC maintenance.",
            "Heads up, building closes at 6 PM tonight for HVAC work.",
        ],
        "preserve": ["6", "PM", "HVAC"],
    },
    {
        "source": "The committee has determined that additional research is necessary before a final decision can be rendered.",
        "references": [
            "The committee needs more research before making a decision.",
            "They decided they need to do more research before deciding.",
        ],
        "preserve": ["research", "decision"],
    },
]

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PROFESSIONAL MODE — should make text polished, clear, business-appropriate
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PROFESSIONAL_SAMPLES = [
    {
        "source": "hey so the numbers look pretty good this quarter, revenue is up like 15% and we crushed our targets",
        "references": [
            "This quarter's results are strong — revenue increased 15%, exceeding our targets.",
            "Our quarterly performance has been excellent, with revenue up 15% and all targets met.",
        ],
        "preserve": ["quarter", "revenue", "15%", "targets"],
    },
    {
        "source": "yeah so basically the server crashed at 2am and it took us forever to fix it, prob like 3 hours",
        "references": [
            "The server experienced an outage at 2:00 AM, and restoration took approximately three hours.",
            "We had a server outage at 2 AM that required approximately three hours to resolve.",
        ],
        "preserve": ["server", "2", "three hours"],
    },
    {
        "source": "can you send me that thing we talked about? i need it for the presentation tmrw",
        "references": [
            "Could you please send me the document we discussed? I need it for tomorrow's presentation.",
            "Would you mind sending the materials we discussed? I'll need them for my presentation tomorrow.",
        ],
        "preserve": ["send", "presentation", "tomorrow"],
    },
    {
        "source": "tbh i dont think this approach is gonna work, we should prob try something else",
        "references": [
            "I have concerns about the viability of this approach. I'd recommend exploring alternative options.",
            "In my assessment, this approach may not be effective. I suggest we consider alternatives.",
        ],
        "preserve": ["approach", "alternative"],
    },
    {
        "source": "the new hire is super smart and picks things up really fast, def a great addition to the team",
        "references": [
            "The new hire has demonstrated strong aptitude and a quick learning curve. They're a valuable addition to the team.",
            "Our new team member has shown excellent capability and adapts quickly. A strong addition to the team.",
        ],
        "preserve": ["new hire", "team"],
    },
    {
        "source": "sorry but we can't do that, the budget won't allow it and frankly it's not worth the effort",
        "references": [
            "Unfortunately, this falls outside our current budget constraints, and the expected return doesn't justify the investment.",
            "I'm afraid this isn't feasible given our budget limitations, and the cost-benefit analysis doesn't support it.",
        ],
        "preserve": ["budget"],
    },
    {
        "source": "just wanted to give u a heads up that the client is kinda unhappy with the latest deliverable",
        "references": [
            "I wanted to flag that the client has expressed dissatisfaction with the latest deliverable.",
            "Please be aware that the client has raised concerns about the most recent deliverable.",
        ],
        "preserve": ["client", "deliverable"],
    },
    {
        "source": "we need to figure out why users keep dropping off at the checkout page, its hurting our conversion rate big time",
        "references": [
            "We need to investigate the high drop-off rate on our checkout page, as it's significantly impacting our conversion metrics.",
            "Our checkout page drop-off rate requires investigation — it's having a substantial negative impact on conversions.",
        ],
        "preserve": ["checkout", "drop-off", "conversion"],
    },
    # Already professional — should be mostly unchanged
    {
        "source": "Please find attached the quarterly report for your review.",
        "references": [
            "Please find attached the quarterly report for your review.",
            "Attached is the quarterly report for your review.",
        ],
        "preserve": ["quarterly report", "review"],
    },
    {
        "source": "We appreciate your continued partnership and look forward to future collaboration.",
        "references": [
            "We appreciate your continued partnership and look forward to future collaboration.",
        ],
        "preserve": ["partnership", "collaboration"],
    },
    # Technical slack messages
    {
        "source": "the deploy broke prod, we're rolling back now. seems like the db migration script had a bug",
        "references": [
            "A production incident occurred during deployment — we're executing a rollback. The root cause appears to be a bug in the database migration script.",
            "The deployment caused a production issue. We are currently rolling back. Initial analysis points to a defect in the database migration script.",
        ],
        "preserve": ["production", "rollback", "database migration", "bug"],
    },
    {
        "source": "lol the intern fixed that bug that's been open for 6 months, nobody else could figure it out",
        "references": [
            "Our intern resolved a long-standing bug that had been open for six months — a notable achievement that the rest of the team had been unable to address.",
            "Impressively, the intern resolved a six-month-old bug that had stumped the rest of the team.",
        ],
        "preserve": ["intern", "bug", "six months"],
    },
    {
        "source": "idk if we should go with AWS or GCP for this, both have pros and cons. thoughts?",
        "references": [
            "I'd like to discuss the tradeoffs between AWS and GCP for this project. Both platforms have distinct advantages. What are your thoughts?",
            "We should evaluate AWS versus GCP for this initiative — each has its merits. I'd welcome your input.",
        ],
        "preserve": ["AWS", "GCP"],
    },
    {
        "source": "ngl the product launch went way better than expected, tons of signups on day one",
        "references": [
            "The product launch exceeded expectations, with significant signup volume on the first day.",
            "I'm pleased to report that the product launch performed above expectations, generating strong day-one signups.",
        ],
        "preserve": ["product launch", "signups", "day one"],
    },
    {
        "source": "pls make sure u test everything before pushing to main, we had too many bugs last sprint",
        "references": [
            "Please ensure thorough testing before merging to main. We experienced an elevated number of defects last sprint and need to improve our quality gates.",
            "Please run comprehensive tests before pushing to main. Last sprint's bug count was higher than acceptable.",
        ],
        "preserve": ["test", "main", "bugs", "sprint"],
    },
]
