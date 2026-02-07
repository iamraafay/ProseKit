# ProseKit LLM Quality Test Results

**Model:** mlx-community/Qwen3-8B-4bit

**Date:** 2026-02-06 14:37


## Sample 1: Slack message with typos

**Original:**
> hey can u take a look at the PR when u get a chance? i think theres a bug in the auth flow where its not redirecting properly after login. also the tests are failing on CI but i think its unrelated

### Grammar (4.75s)

> hey can u take a look at the PR when u get a chance? i think theres a bug in the auth flow where its not redirecting properly after login. also the tests are failing on CI but i think its unrelated

### Concise (1.8s)

> hey can you take a look at the PR when you get a chance? i think there's a bug in the auth flow where it's not redirecting properly after login. also the tests are failing on CI but i think it's unrelated

### Casual (1.79s)

> hey can you take a look at the PR when you get a chance? i think there's a bug in the auth flow where it's not redirecting properly after login. also the tests are failing on CI but i think it's unrelated

### Professional (1.97s)

> Can you take a look at the PR when you get a chance? I think there's a bug in the auth flow where it's not redirecting properly after login. Also, the tests are failing on CI, but I think it's unrelated.

---

## Sample 2: Email with grammar errors

**Original:**
> Hi John, I wanted to follow up on our meeting from yesterday. Me and the team has been working on the proposal and we think their are some areas where we could improved. I would appreciate if you could review it and let me know you're thoughts by Friday.

### Grammar (2.49s)

> Hi John, I wanted to follow up on our meeting from yesterday. Me and the team has been working on the proposal and we think there are some areas where we could improved. I would appreciate if you could review it and let me know your thoughts by Friday.

### Concise (2.49s)

> Hi John, I wanted to follow up on our meeting from yesterday. Me and the team have been working on the proposal and think there are some areas where we could improve. I would appreciate if you could review it and let me know your thoughts by Friday.

### Casual (2.41s)

> Hi John, I wanted to follow up on our meeting from yesterday. Me and the team have been working on the proposal and we think there are some areas where we could improve. I would appreciate if you could review it and let me know your thoughts by Friday.

### Professional (2.55s)

> Hi John, I wanted to follow up on our meeting from yesterday. Me and the team have been working on the proposal and we think there are some areas where we could improve. I would appreciate if you could review it and let me know your thoughts by Friday.

---

## Sample 3: PR description (rough notes)

**Original:**
> added retry logic for API calls. before this if the call failed it would just crash. now it retries 3 times with exponential backoff. also fixed the bug where the timeout wasnt being respected. changed the default timeout from 30s to 10s because 30 was too long and users were complaining

### Grammar (2.79s)

> added retry logic for API calls. before this, if the call failed it would just crash. now it retries 3 times with exponential backoff. also fixed the bug where the timeout wasn't being respected. changed the default timeout from 30s to 10s because 30 was too long and users were complaining

### Concise (2.8s)

> Added retry logic for API calls. Previously, failed calls would crash the app. Now it retries 3 times with exponential backoff. Also fixed a bug where timeout wasn't respected. Changed default timeout from 30s to 10s as 30s was too long and users were complaining.

### Casual (2.97s)

> added retry logic for API calls. before, if the call failed it would just crash. now it retries 3 times with exponential backoff. also fixed the bug where the timeout wasn't being respected. changed the default timeout from 30s to 10s because 30 was too long and users were complaining.

### Professional (2.94s)

> Added retry logic for API calls. Previously, if the call failed, it would just crash. Now it retries 3 times with exponential backoff. Also fixed the bug where the timeout wasn't being respected. Changed the default timeout from 30s to 10s because 30 was too long and users were complaining.

---

## Sample 4: iMessage (very casual)

**Original:**
> yo did u see what happened at the meeting today?? mike basically said the whole project is getting scrapped lol. im kinda stressed about it ngl. wanna grab coffee tmrw and talk about it?

### Grammar (2.14s)

> Did you see what happened at the meeting today?? Mike basically said the whole project is getting scrapped lol. I'm kinda stressed about it ngl. Wanna grab coffee tomorrow and talk about it?

### Concise (2.14s)

> Did you see what happened at the meeting today?? Mike basically said the whole project is getting scrapped lol. I'm kinda stressed about it ngl. Wanna grab coffee tomorrow and talk about it?

### Casual (2.31s)

> yo did u see what happened at the meeting today?? mike basically said the whole project is getting scrapped lol. im kinda stressed about it ngl. wanna grab coffee tmrw and talk about it?

### Professional (2.13s)

> Did you see what happened at the meeting today? Mike basically said the whole project is getting scrapped. I'm kinda stressed about it, NGL. Wanna grab coffee tomorrow and talk about it?

---

## Sample 5: Non-native English speaker

**Original:**
> I am writing to inform you that the delivery of the goods will be delay by approximately 2 weeks due to supply chain issue. We are very sorry for the inconvenient and we will do our best to expedite the process. Please do not hesitate to contact me if you have any question.

### Grammar (2.73s)

> I am writing to inform you that the delivery of the goods will be delayed by approximately 2 weeks due to supply chain issue. We are very sorry for the inconvenience and we will do our best to expedite the process. Please do not hesitate to contact me if you have any question.

### Concise (2.84s)

> I am writing to inform you that the delivery of the goods will be delayed by approximately two weeks due to a supply chain issue. We are very sorry for the inconvenience and will do our best to expedite the process. Please do not hesitate to contact me if you have any questions.

### Casual (2.9s)

> I am writing to inform you that the delivery of the goods will be delayed by approximately 2 weeks due to a supply chain issue. We are very sorry for the inconvenience and we will do our best to expedite the process. Please do not hesitate to contact me if you have any questions.

### Professional (3.17s)

> I am writing to inform you that the delivery of the goods will be delayed by approximately two weeks due to supply chain issues. We are very sorry for the inconvenience and will do our best to expedite the process. Please do not hesitate to contact me if you have any questions.

---

## Sample 6: Already well-written (should not overcorrect)

**Original:**
> The new authentication system uses JWT tokens with a 24-hour expiry window. When a token expires, the client automatically refreshes it using the stored refresh token. If the refresh token has also expired, the user is redirected to the login page.

### Grammar (2.67s)

> The new authentication system uses JWT tokens with a 24-hour expiry window. When a token expires, the client automatically refreshes it using the stored refresh token. If the refresh token has also expired, the user is redirected to the login page.

### Concise (2.42s)

> The new authentication system uses JWT tokens with a 24-hour expiry. When a token expires, the client automatically refreshes it using the stored refresh token. If the refresh token has expired, the user is redirected to the login page.

### Casual (2.58s)

> The new authentication system uses JWT tokens that expire after 24 hours. When a token expires, the client automatically refreshes it using the stored refresh token. If the refresh token has also expired, the user is redirected to the login page.

### Professional (2.51s)

> The new authentication system uses JWT tokens with a 24-hour expiry window. When a token expires, the client automatically refreshes it using the stored refresh token. If the refresh token has also expired, the user is redirected to the login page.

---

## Sample 7: Long rambling text

**Original:**
> So basically what I was thinking is that we should probably maybe consider looking into the possibility of potentially restructuring the way we handle the onboarding flow because right now it's kind of confusing for new users and I've been hearing from a lot of people that they don't really understand what they're supposed to do after they sign up and I think if we simplified it a bit it would really help with our retention numbers which have been kind of going down lately.

### Grammar (3.83s)

> So basically what I was thinking is that we should probably maybe consider looking into the possibility of potentially restructuring the way we handle the onboarding flow because right now it's kind of confusing for new users and I've been hearing from a lot of people that they don't really understand what they're supposed to do after they sign up and I think if we simplified it a bit it would really help with our retention numbers which have been kind of going down lately.

### Concise (3.03s)

> So basically, I think we should consider restructuring the onboarding flow. The current process is confusing for new users, and many aren't clear on what to do after signing up. Simplifying it could help improve retention, which has been declining.

### Casual (3.62s)

> So basically what I was thinking is that we should probably consider looking into the possibility of restructuring the onboarding flow. Right now it's a bit confusing for new users, and I've been hearing from a lot of people that they don't really understand what to do after they sign up. I think if we simplified it a bit, it would really help with our retention numbers, which have been going down lately.

### Professional (3.95s)

> So basically what I was thinking is that we should probably consider looking into the possibility of restructuring the way we handle the onboarding flow. Right now, it's kind of confusing for new users, and I've been hearing from a lot of people that they don't really understand what they're supposed to do after they sign up. I think if we simplified it a bit, it would really help with our retention numbers, which have been going down lately.

---

## Sample 8: Technical with special terms

**Original:**
> the kubectl apply -f deployment.yaml command is failing with a OOMKilled error. i think we need to bump the memory limits in the pod spec. currently its set to 512Mi but the container is using like 800Mi at peak. @sarah can you check the grafana dashboard for the exact numbers?

### Grammar (3.41s)

> the kubectl apply -f deployment.yaml command is failing with a OOMKilled error. i think we need to bump the memory limits in the pod spec. currently its set to 512Mi but the container is using like 800Mi at peak. @sarah can you check the grafana dashboard for the exact numbers?

### Concise (3.33s)

> The kubectl apply -f deployment.yaml command is failing with an OOMKilled error. I think we need to bump the memory limits in the pod spec. Currently it's set to 512Mi but the container is using around 800Mi at peak. @sarah can you check the grafana dashboard for the exact numbers?

### Casual (3.41s)

> the kubectl apply -f deployment.yaml command is failing with an OOMKilled error. i think we need to bump the memory limits in the pod spec. currently it's set to 512Mi but the container is using like 800Mi at peak. @sarah can you check the grafana dashboard for the exact numbers?

### Professional (3.56s)

> The `kubectl apply -f deployment.yaml` command is failing with an OOMKilled error. I think we need to bump the memory limits in the pod spec. Currently, it's set to 512Mi, but the container is using around 800Mi at peak. @sarah can you check the grafana dashboard for the exact numbers?

---

## Sample 9: Mixed languages / proper nouns

**Original:**
> We need to update the README.md for the ProseKit repo. Also @raafay mentioned that the API endpoint at https://api.example.com/v2/rewrite needs to be documented. The François Müller branch has the latest changes.

### Grammar (2.53s)

> We need to update the README.md for the ProseKit repo. Also @raafay mentioned that the API endpoint at https://api.example.com/v2/rewrite needs to be documented. The François Müller branch has the latest changes.

### Concise (2.66s)

> We need to update the README.md for the ProseKit repo. Also @raafay mentioned that the API endpoint at https://api.example.com/v2/rewrite needs to be documented. The François Müller branch has the latest changes.

### Casual (2.61s)

> We need to update the README.md for the ProseKit repo. Also @raafay mentioned that the API endpoint at https://api.example.com/v2/rewrite needs to be documented. The François Müller branch has the latest changes.

### Professional (2.62s)

> We need to update the README.md for the ProseKit repo. Also @raafay mentioned that the API endpoint at https://api.example.com/v2/rewrite needs to be documented. The François Müller branch has the latest changes.

---

## Sample 10: Very short message

**Original:**
> sounds good, lets do it tmrw

### Grammar (1.45s)

> Sounds good, let's do it tmrw.

### Concise (1.44s)

> Sounds good, let's do it tomorrow.

### Casual (1.42s)

> Sounds good, let's do it tomorrow.

### Professional (1.42s)

> Sounds good, let's do it tomorrow.

---
