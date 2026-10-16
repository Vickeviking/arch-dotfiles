export type DeskStatus = {
  host: string
  tailscale: boolean
  firewall: boolean
  updates: number | null
  checkedUpdatesAt: number
}

declare module 'claude-code' {
  interface PluginState {
    'rain-city': { status: DeskStatus | null; turnStartedAt: number }
  }
}
