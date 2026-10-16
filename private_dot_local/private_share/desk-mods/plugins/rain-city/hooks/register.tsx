import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { DeskStatus } from '../types'

const status = atom({ plugin: 'rain-city', key: 'status' } as const, null)
const turnStartedAt = atom({ plugin: 'rain-city', key: 'turnStartedAt' } as const, 0)

const LONG_TURN_MS = 60_000
const UPDATES_EVERY_MS = 30 * 60_000
const CHIME = '/usr/share/sounds/freedesktop/stereo/complete.oga'
const HOME = '/home/vango'

/** Parses the count out of desk-updates' JSON ("󰚰 5" → 5, "" → 0). */
export function parseUpdates(json: string): number | null {
  try {
    const { text } = JSON.parse(json) as { text?: string }
    const n = (text ?? '').match(/\d+/)
    return n ? Number(n[0]) : 0
  } catch {
    return null
  }
}

/** "1m 42s" / "48s" */
export function formatDuration(ms: number): string {
  const s = Math.round(ms / 1000)
  return s >= 60 ? `${Math.floor(s / 60)}m ${s % 60}s` : `${s}s`
}

/**
 * Writes the fast facts (host, tailscale, firewall) right away, then, when due or forced,
 * the slow update count (checkupdates hits the network) in a second write.
 */
async function refresh($: EngineInterface, updatesWhen: 'due' | 'now' | 'never' = 'due') {
  const now = await $.clock.now()
  const prev: DeskStatus | null = await read($, status)

  const run = async (argv: string[], timeoutMs = 5000) => {
    try {
      return await $.process.run(argv, { timeoutMs })
    } catch {
      return { exitCode: -1, stdout: '', stderr: '' }
    }
  }

  let host = 'this machine'
  try {
    host = (await $.fs.read('/etc/hostname')).trim() || host
  } catch {}
  const tailscale = (await run(['tailscale', 'status', '--self', '--peers=false'])).exitCode === 0
  let firewall = false
  try {
    firewall = /^ENABLED=yes/m.test(await $.fs.read('/etc/ufw/ufw.conf'))
  } catch {}

  const updates = prev?.updates ?? null
  const checkedUpdatesAt = prev?.checkedUpdatesAt ?? 0
  await update($, status, () => ({ host, tailscale, firewall, updates, checkedUpdatesAt }))

  const isDue = updatesWhen === 'now' || (updatesWhen === 'due' && now - checkedUpdatesAt > UPDATES_EVERY_MS)
  if (isDue) {
    const fresh = parseUpdates((await run([`${HOME}/.local/bin/desk-updates`], 30_000)).stdout)
    await update($, status, s => (s ? { ...s, updates: fresh, checkedUpdatesAt: now } : s))
  }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const started = await next(e)
    await $.command.register({
      name: 'desk-theme',
      description: 'Switch the desktop + Claude theme (no name: list themes)',
    })
    await refresh($, 'never')
    void refresh($, 'now')
    return started
  })

  on('command.run', { command: 'desk-theme' }, async ($, e) => {
    const args = e.args.trim().split(/\s+/).filter(Boolean)
    const r = await $.process.run([`${HOME}/.local/bin/desk-theme`, ...args], { timeoutMs: 20_000 })
    const out = (r.stdout || r.stderr).trim()
    return { text: args.length ? out : `Themes (* = active):\n${out}\n\nUse: /desk-theme <name>` }
  })

  on('prompt.submit', async ($, e, next) => {
    const now = await $.clock.now()
    await update($, turnStartedAt, () => now)
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    const done = await next(e)
    const started = await read($, turnStartedAt)
    const took = (await $.clock.now()) - started
    if (started > 0 && took >= LONG_TURN_MS) {
      $.ui.toast(`Claude finished · ${formatDuration(took)}`)
      void $.process.run(['paplay', CHIME], { timeoutMs: 5000 }).catch(() => {})
    }
    void refresh($)
    return done
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const s: DeskStatus | null = await read($, status)
    if (e.props.hasSurvey || s === null) {
      return next(e)
    }
    const { Box, Text } = $.ui.resolve(e)
    const dot = (isOn: boolean) => (isOn ? 'success' : 'error')

    return (
      <Box flexDirection="row" gap={2}>
        <Text color="inactive">{s.host}</Text>
        <Text color={dot(s.tailscale)}>● tailscale</Text>
        <Text color={dot(s.firewall)}>● firewall</Text>
        {s.updates === null ? null : s.updates === 0 ? (
          <Text color="inactive">up to date</Text>
        ) : (
          <Text color="claude">{s.updates} updates</Text>
        )}
      </Box>
    )
  })
}
