"""
builtin_samples.py — Hand-curated grammar error test cases.

Used as a fallback when JFLEG can't be downloaded, or for quick smoke tests.
Each sample has: source (with errors), and 1-2 reference corrections.

These cover common error types ProseKit will encounter in the wild:
- Homophones (their/they're/there, your/you're, its/it's)
- Subject-verb agreement
- Tense consistency
- Missing/extra articles
- Spelling errors
- Run-on sentences
- Missing punctuation
- Informal/texting shortcuts
"""

BUILTIN_SAMPLES = [
    # ─── Homophones ────────────────────────────────────────────────
    {
        "source": "Their going to the park with there friends.",
        "references": [
            "They're going to the park with their friends.",
        ],
    },
    {
        "source": "Your the best person I no.",
        "references": [
            "You're the best person I know.",
        ],
    },
    {
        "source": "Its been a long day and the dog lost it's bone.",
        "references": [
            "It's been a long day and the dog lost its bone.",
        ],
    },
    {
        "source": "Who's book is this? I think its your's.",
        "references": [
            "Whose book is this? I think it's yours.",
        ],
    },

    # ─── Subject-Verb Agreement ────────────────────────────────────
    {
        "source": "The team are going to the finals and they is very excited.",
        "references": [
            "The team is going to the finals and they are very excited.",
            "The team are going to the finals and they are very excited.",
        ],
    },
    {
        "source": "Each of the students have their own laptop.",
        "references": [
            "Each of the students has their own laptop.",
        ],
    },
    {
        "source": "There is many reasons why this wont work.",
        "references": [
            "There are many reasons why this won't work.",
        ],
    },

    # ─── Tense Errors ─────────────────────────────────────────────
    {
        "source": "I goes to the store yesterday and buyed some milk.",
        "references": [
            "I went to the store yesterday and bought some milk.",
        ],
    },
    {
        "source": "She was walking home when she sees a cat and picked it up.",
        "references": [
            "She was walking home when she saw a cat and picked it up.",
        ],
    },
    {
        "source": "He has went to the gym every day last week.",
        "references": [
            "He went to the gym every day last week.",
            "He has gone to the gym every day last week.",
        ],
    },

    # ─── Spelling Errors ──────────────────────────────────────────
    {
        "source": "I recieved the accomodation details for the confrence.",
        "references": [
            "I received the accommodation details for the conference.",
        ],
    },
    {
        "source": "The goverment made an annoucement about the enviroment.",
        "references": [
            "The government made an announcement about the environment.",
        ],
    },
    {
        "source": "She definately didnt know about the occurence.",
        "references": [
            "She definitely didn't know about the occurrence.",
        ],
    },

    # ─── Missing/Extra Articles ────────────────────────────────────
    {
        "source": "I need go to store to buy a bread.",
        "references": [
            "I need to go to the store to buy bread.",
            "I need to go to the store to buy some bread.",
        ],
    },
    {
        "source": "She is best student in the class.",
        "references": [
            "She is the best student in the class.",
        ],
    },

    # ─── Punctuation ──────────────────────────────────────────────
    {
        "source": "Lets eat grandma before she gets cold",
        "references": [
            "Let's eat, grandma, before she gets cold.",
            "Let's eat, Grandma, before she gets cold.",
        ],
    },
    {
        "source": "I like cooking my family and my pets",
        "references": [
            "I like cooking, my family, and my pets.",
        ],
    },
    {
        "source": "however I think that were going to be late dont you agree",
        "references": [
            "However, I think that we're going to be late. Don't you agree?",
            "However, I think that we're going to be late, don't you agree?",
        ],
    },

    # ─── Already Correct (should be returned unchanged) ───────────
    {
        "source": "The weather is beautiful today.",
        "references": [
            "The weather is beautiful today.",
        ],
    },
    {
        "source": "I'm going to finish this project by Friday.",
        "references": [
            "I'm going to finish this project by Friday.",
        ],
    },
    {
        "source": "She quickly ran across the street to catch the bus.",
        "references": [
            "She quickly ran across the street to catch the bus.",
        ],
    },

    # ─── Real-World Chat Messages (ProseKit's primary use case) ───
    {
        "source": "hey can u send me the file i need it asap thx",
        "references": [
            "Hey, can you send me the file? I need it ASAP. Thanks.",
            "Hey, can you send me the file? I need it ASAP, thanks.",
        ],
    },
    {
        "source": "im gonna be late to the meeting sry something came up",
        "references": [
            "I'm going to be late to the meeting, sorry, something came up.",
            "I'm gonna be late to the meeting, sorry, something came up.",
        ],
    },
    {
        "source": "lmk when your free to talk about the project",
        "references": [
            "Let me know when you're free to talk about the project.",
            "LMK when you're free to talk about the project.",
        ],
    },
    {
        "source": "did you seen the email from the client? its importent",
        "references": [
            "Did you see the email from the client? It's important.",
        ],
    },

    # ─── Mixed Errors (multiple types) ────────────────────────────
    {
        "source": "Me and him goes to the libary every tuesdays to studie for are exam.",
        "references": [
            "He and I go to the library every Tuesday to study for our exam.",
        ],
    },
    {
        "source": "The companys profits has droped significently since they're CEO leaved.",
        "references": [
            "The company's profits have dropped significantly since their CEO left.",
        ],
    },
    {
        "source": "I should of went to the docter but I didnt had no time.",
        "references": [
            "I should have gone to the doctor, but I didn't have time.",
            "I should have gone to the doctor but I didn't have any time.",
        ],
    },
    {
        "source": "Noone could of predicted that the wether would be so bad on they're wedding day.",
        "references": [
            "No one could have predicted that the weather would be so bad on their wedding day.",
        ],
    },

    # ─── Technical Writing ────────────────────────────────────────
    {
        "source": "The API endpoint returns a JSON object which contain the users data.",
        "references": [
            "The API endpoint returns a JSON object which contains the user's data.",
            "The API endpoint returns a JSON object that contains the user's data.",
        ],
    },
    {
        "source": "Please insure that all tests passes before merging the pull request.",
        "references": [
            "Please ensure that all tests pass before merging the pull request.",
        ],
    },
]
