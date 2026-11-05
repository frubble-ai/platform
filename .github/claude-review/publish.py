"""Carries out the reconciled Claude review on the pull request.

Run by .github/workflows/claude-code-review.yml, taken from the base branch like the rules. Two
Claude steps came before it, kept apart on purpose:

1. the review, blind to earlier comments, returned every finding present at the head commit;
2. the reconcile step matched those findings to this workflow's threads by meaning, and chose an
   action for each thread: keep, resolve or reopen, with an optional reply.

This script writes, and holds both to hard rules whatever they said:

- only this workflow's own threads are replied to, resolved or reopened;
- a thread a person resolved is never reopened; only an open one is resolved;
- a matched open thread is resolved only when its latest reply is a person's (a dispute);
- a thread this workflow resolved is reopened when a finding matches it, and an open thread no
  finding matches is resolved, whatever the reconcile step chose for it; a matched thread it
  resolved by accepting a dispute is kept or reopened as the reconcile step judged (with no
  judgement, nothing is published), and every accepted dispute gets a marked reply;
- a finding the reconcile step matched is never posted; every other one is, all in one review,
  except one on the exact line of a thread that stays open, sharing a lens with it;
- a finding on a line the diff does not carry moves to the nearest one it does; one with no line
  to sit on at all is listed in the verdict, and still counts as open;
- the verdict follows the threads: changes are requested while any thread of this workflow is
  open, and approved, after its earlier requests for changes are dismissed, when none is. An
  unchanged request for changes is edited in place; an older verdict is dismissed and collapsed.

Every write first checks that the pull request is still at the head this run reviewed, and stops
the run when a newer push has landed.

Prints `open=<n>` to $GITHUB_OUTPUT for the step that holds the check red.
"""

import json
import os
import re
import subprocess
import sys

MARKER = "<!-- claude-review -->"
VERDICT_MARKER = "<!-- claude-review-verdict -->"
SUMMARY_MARKER = "<!-- claude-review-summary -->"
# On this workflow's reply when it accepts a dispute and resolves the thread: a later run that
# reports the same defect keeps the thread resolved instead of reopening it.
ACCEPTED_MARKER = "<!-- claude-review-accepted -->"
BOT = "github-actions[bot]"
BOT_GRAPHQL = "github-actions"
# GitHub names the bot both ways: `github-actions` as a comment's author, `github-actions[bot]`
# as the one who resolved a thread.
BOT_LOGINS = {BOT, BOT_GRAPHQL}
REQUIRED = "<sub>Required before merge: fix it, or reply with why it does not apply.</sub>"

REPO = os.environ["GITHUB_REPOSITORY"]
PR = os.environ["PR"]
HEAD = os.environ["HEAD_SHA"]
API = f"repos/{REPO}/pulls/{PR}"


def still_head():
    """Stops the run when the pull request has moved past the commit this run reviewed."""
    done = subprocess.run(["gh", "api", API, "--jq", ".head.sha"], capture_output=True, text=True)
    live = done.stdout.strip()
    if done.returncode != 0 or live != HEAD:
        sys.exit(f"the pull request's head is now {live[:7] or 'unknown'}, not {HEAD[:7]}: this run is "
                 "superseded, so it writes nothing more")


def gh(*args, payload=None, check=True):
    """Calls `gh api`, sending `payload` as the JSON body, and returns the parsed answer.

    Before every write, it checks the pull request is still at the reviewed head. That narrows the
    window for a stale write to one read and one write; it cannot stop a write already sent.
    """
    if ("-X" in args and args[args.index("-X") + 1] != "GET") or any(
            str(arg).startswith("query=mutation") for arg in args):
        still_head()
    cmd = ["gh", "api", *args]
    if payload is not None:
        cmd += ["--input", "-"]
    done = subprocess.run(
        cmd,
        input=None if payload is None else json.dumps(payload),
        capture_output=True,
        text=True,
    )
    if done.returncode != 0:
        if check:
            sys.exit(f"gh api {' '.join(args)} failed: {done.stderr.strip()}")
        return None
    out = done.stdout.strip()
    return json.loads(out) if out else None


def paged(path):
    """Every item of a paginated REST list."""
    pages = subprocess.run(
        ["gh", "api", "--paginate", "--slurp", path], capture_output=True, text=True, check=True
    )
    return [item for page in json.loads(pages.stdout) for item in page]


def graphql(query, **variables):
    """Runs a GraphQL query or mutation and returns its `data`."""
    args = ["graphql", "-f", f"query={query}"]
    for key, value in variables.items():
        args += ["-F", f"{key}={value}"]
    return gh(*args)["data"]


def diff_lines(path):
    """The head-side lines a review comment may sit on, per file: added and context lines."""
    lines, current, right = {}, None, 0
    for raw in open(path, encoding="utf-8", errors="replace"):
        if raw.startswith("+++ "):
            name = raw[4:].rstrip("\n")
            current = None if name == "/dev/null" else name.removeprefix("b/")
            if current:
                lines.setdefault(current, set())
        elif raw.startswith("@@"):
            match = re.match(r"@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@", raw)
            right = int(match.group(1)) if match else 0
        elif current and raw.startswith(("+", " ")) and not raw.startswith("+++"):
            lines[current].add(right)
            right += 1
    return lines


def anchor(path, line, valid):
    """Moves a comment onto a line the diff carries, saying where it really belongs."""
    if line in valid.get(path, ()):
        return path, line, ""
    note = f"On `{path}:{line}`:\n\n"
    if valid.get(path):
        return path, min(valid[path], key=lambda candidate: abs(candidate - line)), note
    for other in sorted(valid):
        if valid[other]:
            return other, min(valid[other]), note
    return None, None, note


def lenses(text):
    """The lenses a finding or a comment names: `issue (blocking, security, boundaries)`."""
    match = re.search(r"issue \(blocking,\s*([^)]*)\)", text)
    names = match.group(1) if match else text
    return {name.strip().lower() for name in names.split(",") if name.strip()}


THREADS = """
query($owner: String!, $name: String!, $number: Int!, $endCursor: String) {
  repository(owner: $owner, name: $name) { pullRequest(number: $number) {
    reviewThreads(first: 100, after: $endCursor) {
      pageInfo { hasNextPage endCursor }
      nodes { id isResolved resolvedBy { login } path line originalLine
        comments(first: 1) { nodes { id databaseId author { login } body } } } } } }
}"""


def own_threads():
    """This workflow's review threads: their root comment is the bot's and carries the marker."""
    owner, name = REPO.split("/")
    # Every reply, from the paginated REST list: a thread's comments in GraphQL stop at a page.
    replies = [comment for comment in paged(f"{API}/comments") if comment.get("in_reply_to_id")]
    accepted_roots = {
        comment["in_reply_to_id"] for comment in replies
        if (comment.get("user") or {}).get("login") in BOT_LOGINS and ACCEPTED_MARKER in (comment.get("body") or "")
    }
    # Who wrote each root's latest reply: a dispute is a person's reply, never this workflow's.
    latest_author = {}
    for comment in sorted(replies, key=lambda comment: comment.get("created_at") or ""):
        latest_author[comment["in_reply_to_id"]] = (comment.get("user") or {}).get("login")
    threads, cursor = [], None
    while True:
        extra = {"endCursor": cursor} if cursor else {}
        page = graphql(THREADS, owner=owner, name=name, number=PR, **extra)
        block = page["repository"]["pullRequest"]["reviewThreads"]
        for thread in block["nodes"]:
            roots = thread["comments"]["nodes"]
            # A deleted account's comment has no author.
            author = (roots[0].get("author") or {}).get("login") if roots else None
            if roots and author in BOT_LOGINS and MARKER in roots[0]["body"]:
                thread["root"] = roots[0]
                thread["accepted"] = roots[0]["databaseId"] in accepted_roots
                author_of_latest = latest_author.get(roots[0]["databaseId"])
                thread["disputed"] = author_of_latest is not None and author_of_latest not in BOT_LOGINS
                thread["lenses"] = lenses(roots[0]["body"])
                line = thread["line"] or thread["originalLine"] or 0
                thread["places"] = {(thread["path"], line)}
                real = re.match(r"On `?([^`\s]+?):(\d+)`?:", roots[0]["body"])
                if real:
                    thread["places"].add((real.group(1), int(real.group(2))))
                threads.append(thread)
        if not block["pageInfo"]["hasNextPage"]:
            return threads
        cursor = block["pageInfo"]["endCursor"]


def resolve(thread):
    """Resolves a review thread."""
    graphql("mutation($id: ID!) { resolveReviewThread(input: {threadId: $id}) { thread { id } } }",
            id=thread["id"])


def reopen(thread):
    """Reopens a resolved review thread."""
    graphql("mutation($id: ID!) { unresolveReviewThread(input: {threadId: $id}) { thread { id } } }",
            id=thread["id"])


def main():
    """Carries out the reconcile decisions, posts new findings and the verdict, and prints `open`."""
    result = json.loads(os.environ["RESULT"])
    decisions = json.loads(os.environ["DECISIONS"])
    valid = diff_lines(os.environ["DIFF"])
    threads = own_threads()
    by_id = {thread["id"]: thread for thread in threads}
    findings = [
        {**item, "lenses": lenses(item.get("lens", "")) or lenses(item["body"])}
        for item in result.get("findings", [])
    ]

    # The reconcile step's matches, held to one thread per finding and one finding per thread.
    matched_finding, matched_thread = {}, {}
    for match in decisions.get("matches", []):
        index, thread_id = match.get("finding"), match.get("thread")
        if not isinstance(index, int) or not 0 <= index < len(findings) or thread_id not in by_id:
            print(f"ignored match {match}: no such finding or thread")
            continue
        if index in matched_finding or thread_id in matched_thread:
            print(f"ignored match {match}: already matched")
            continue
        matched_finding[index] = thread_id
        matched_thread[thread_id] = index

    # Each thread's action, held to what that thread allows.
    actions = {item.get("thread"): item for item in decisions.get("threads", [])}
    # A matched thread resolved by accepting a dispute needs the reconcile step's judgement, never
    # a default: checked before anything is written.
    for thread in threads:
        by_person = thread["isResolved"] and (thread["resolvedBy"] or {}).get("login") not in BOT_LOGINS
        if (thread["id"] in matched_thread and thread["isResolved"] and not by_person and thread["accepted"]
                and actions.get(thread["id"], {}).get("action") not in ("keep", "reopen")):
            sys.exit(f"the reconcile step gave no keep or reopen for accepted thread {thread['id']} "
                     f"({thread['path']}); nothing was published")
    for thread in threads:
        where = f"{thread['path']}:{thread['line'] or thread['originalLine']}"
        decision = actions.get(thread["id"], {})
        action = decision.get("action", "keep")
        by_person = thread["isResolved"] and (thread["resolvedBy"] or {}).get("login") not in BOT_LOGINS
        # The reconcile table, held whatever the reconcile step chose: a defect that is back
        # reopens this workflow's own resolved thread, and a defect that is gone resolves its
        # open one. Two cases stay the reconcile step's call, judged against the code: a matched
        # open thread (a dispute), and a matched thread resolved by accepting a dispute (does
        # the reply it accepted still hold at the head?).
        matched = thread["id"] in matched_thread
        if matched and thread["isResolved"] and not by_person:
            if not thread["accepted"]:
                action = "reopen"
        elif not matched and not thread["isResolved"]:
            action = "resolve"
        elif matched and not thread["isResolved"] and action == "resolve" and not thread["disputed"]:
            # A matched open thread is resolved only by accepting a person's dispute.
            print(f"kept {where}: resolving a present finding needs a person's reply to accept")
            action, decision = "keep", {**decision, "reply": ""}
        accepting = matched and action == "resolve" and not thread["isResolved"]
        if action == "resolve" and not thread["isResolved"]:
            resolve(thread)
            thread["isResolved"] = True
            print(f"resolved {where}")
        elif action == "reopen" and thread["isResolved"] and not by_person:
            reopen(thread)
            thread["isResolved"] = False
            print(f"reopened {where}")
        elif action in ("resolve", "reopen"):
            print(f"kept {where}: cannot {action} a thread that is "
                  f"{'resolved by a person' if by_person else ('resolved' if thread['isResolved'] else 'open')}")
        else:
            print(f"kept {where} ({'resolved' if thread['isResolved'] else 'open'})")
        reply = (decision.get("reply") or "").strip()
        if accepting and not reply:
            # An accepted dispute is always marked, so a later run knows it was accepted.
            reply = "The reply above holds, so this finding is resolved."
        if reply:
            accepted = f"\n{ACCEPTED_MARKER}" if accepting else ""
            gh(f"{API}/comments/{thread['root']['databaseId']}/replies", "-X", "POST",
               payload={"body": f"{reply}\n{MARKER}{accepted}"})
            print(f"replied on {where}")

    open_threads = [thread for thread in threads if not thread["isResolved"]]

    # New findings: posted, all in one review.
    comments, unplaced = [], []
    for index, finding in enumerate(findings):
        if index in matched_finding:
            continue
        # A safety net for a match the reconcile step missed: only a thread no other finding
        # matched can be this finding's twin.
        twin = next((thread for thread in open_threads
                     if thread["id"] not in matched_thread
                     and (finding["path"], finding["line"]) in thread["places"]
                     and thread["lenses"] & finding["lenses"]), None)
        if twin:
            print(f"skipped {finding['path']}:{finding['line']}: the same spot as open thread {twin['id']}")
            continue
        path, line, note = anchor(finding["path"], finding["line"], valid)
        if path is None:
            unplaced.append(f"- On `{finding['path']}:{finding['line']}`: {' '.join(finding['body'].split())}")
            print(f"listed {finding['path']}:{finding['line']} in the verdict: the diff carries no line to comment on")
            continue
        comments.append({
            "path": path, "line": line, "side": "RIGHT",
            "body": f"{note}{finding['body']}\n\n{REQUIRED}\n{MARKER}",
        })
        print(f"new {finding['path']}:{finding['line']}")

    # The verdict follows the threads: every open one, old or new, is a required finding.
    open_count = len(open_threads) + len(comments) + len(unplaced)
    if open_count:
        event = "REQUEST_CHANGES"
        listed = ("\n\nNo line of the diff can hold these, so they are listed here:\n\n"
                  + "\n".join(unplaced)) if unplaced else ""
        body = (f"❌ **Changes requested** — {open_count} open finding(s).\n\n"
                "Every finding is required: each one blocks the merge until it is fixed, or someone "
                "with write access replies with why it does not apply and resolves its thread. "
                f"Resolve every thread before merging.{listed}\n{VERDICT_MARKER}")
    else:
        event = "APPROVE"
        body = ("✅ **Approved** — no open findings.\n\n"
                "Every finding was required, and every one is resolved. This approval does not "
                f"count toward the merge: a code owner still has to approve.\n{VERDICT_MARKER}")

    verdicts = [
        review for review in paged(f"{API}/reviews")
        if review["user"]["login"] == BOT and VERDICT_MARKER in (review["body"] or "")
        and review["state"] != "DISMISSED"
    ]
    latest = verdicts[-1] if verdicts else None

    if not comments and latest and event == "REQUEST_CHANGES" and latest["state"] == "CHANGES_REQUESTED":
        gh(f"{API}/reviews/{latest['id']}", "-X", "PUT", payload={"body": body})
        print(f"updated verdict {latest['id']} in place: {open_count} open")
        posted = latest
    elif not comments and latest and event == "APPROVE" and latest["state"] in ("APPROVED", "COMMENTED") \
            and latest["body"].startswith("✅"):
        print(f"verdict {latest['id']} already approves")
        posted = latest
    else:
        payload = {"commit_id": HEAD, "event": event, "body": body, "comments": comments}
        posted = gh(f"{API}/reviews", "-X", "POST", payload=payload, check=False)
        if posted is None:
            print(f"GitHub refused {event}; posting the same review as a comment-review")
            posted = gh(f"{API}/reviews", "-X", "POST", payload={**payload, "event": "COMMENT"})
        print(f"posted review {posted['id']} ({posted['state']}) with {len(comments)} comment(s)")

    # One live verdict: every older one is dismissed, where GitHub allows it, and collapsed.
    for review in verdicts:
        if review["id"] == posted["id"]:
            continue
        if review["state"] in ("CHANGES_REQUESTED", "APPROVED"):
            gh(f"{API}/reviews/{review['id']}/dismissals", "-X", "PUT",
               payload={"event": "DISMISS", "message": f"Superseded by the review at {HEAD[:7]}."})
        graphql("mutation($id: ID!) { minimizeComment(input: {subjectId: $id, "
                "classifier: OUTDATED}) { clientMutationId } }", id=review["node_id"])
        print(f"superseded verdict {review['id']}")

    # This workflow never leaves a conversation comment.
    for comment in paged(f"repos/{REPO}/issues/{PR}/comments"):
        if comment["user"]["login"] == BOT and SUMMARY_MARKER in (comment["body"] or ""):
            gh(f"repos/{REPO}/issues/comments/{comment['id']}", "-X", "DELETE")
            print(f"deleted summary comment {comment['id']}")

    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as out:
        out.write(f"open={open_count}\n")
    print(f"open findings: {open_count}")


if __name__ == "__main__":
    main()
