# Tmux Federation

A concept for unified session switching across local and remote tmux instances, treating the host as irrelevant.

## The Problem

When working with both local tmux and remote tmux (e.g., on a nix box via SSH), you're stuck with:
- Nested tmux (different prefixes, unpleasant)
- Multiple terminal windows (defeats the purpose of tmux)
- A "hub" picker model (extra step each time)

## The Concept

Use files as a message-passing system between two tmux instances. SSH's exit becomes the "handoff" moment.

### Key Insight

Sessions are organized with **host affinity** in a ring:
```
[local-a] [local-b] [local-c] [remote-a] [remote-b] [remote-c]
```

Each host manages its own segment. Sync happens at handoff. Single-client assumption eliminates race conditions.

### Flow

```
Local                           Remote
─────                           ──────
\ picker (local + remote)
   ↓ pick remote
detach -E "ssh..."  ─────────→  attach
                                \ picker (remote + local)
                                   ↓ pick local
                    ←───────────  write intent, detach
read intent, attach to it
```

### Implementation Sketch

**Picker script** (`tmux-federation-picker.sh`):
- Gathers sessions from both hosts (local via `tmux list-sessions`, remote via SSH or cached file)
- Presents unified fzf picker
- For local selection: `tmux attach -t session`
- For remote selection:
  1. Write local session list to remote (`scp` to `~/.tmux-federation/peer-sessions`)
  2. `ssh -t remote 'tmux attach -t session'`
  3. On SSH exit, read intent file from remote
  4. Act on intent (attach to requested session, or re-run picker)

**Intent signaling** (on remote side):
- When picker selects a local session, write `host\tsession` to `~/.tmux-federation/intent`
- Then `tmux detach`
- SSH exits, local side reads intent and acts

**Tmux binding**:
```
bind \\ detach-client -E "~/.config/scripts/tmux-federation-picker.sh"
```

### Environment Variables

```bash
# On Mac
export TMUX_FED_SELF="mac"
export TMUX_FED_PEER="nix"  # SSH alias

# On remote nix box
export TMUX_FED_SELF="nix"
export TMUX_FED_PEER="mac"  # SSH alias back (if bidirectional)
```

### Cycling with ( and )

Instead of tmux's internal session ring, maintain a combined list file. Each `(` or `)`:
1. Refresh the combined session list
2. Find current position
3. Calculate next/prev
4. If same host: `switch-client`
5. If different host: write intent + detach (triggers handoff)

### Edge Cases

- **SSH dies unexpectedly**: No intent file → default to re-running picker or attaching to last known session
- **Stale session lists**: Refresh at each picker invocation; use cached `peer-sessions` file if fresh (< 5 min)
- **New sessions**: Only affect your own host's segment of the ring

### Requirements

- SSH key-based auth (BatchMode)
- SSH aliases configured in both directions (for bidirectional switching)
- Same script deployed to both hosts (via shared config repo)

## Status

Concept only. Not implemented. The practical workaround for now is the "hub" model with `detach -E`, accepting the extra picker step when switching hosts.
