import { describe, expect, test } from 'claude-code/testing'

import { formatDuration, parseUpdates } from '../hooks/register'

describe('helpers', () => {
  test('formatDuration', async () => {
    expect(formatDuration(48_000)).toBe('48s')
    expect(formatDuration(102_000)).toBe('1m 42s')
  })
  test('parseUpdates reads desk-updates JSON', async () => {
    expect(parseUpdates('{"text":"󰚰 5","class":"pending"}')).toBe(5)
    expect(parseUpdates('{"text":"","class":"ok"}')).toBe(0)
    expect(parseUpdates('not json')).toBe(null)
  })
})

const PROPS = {
  hasSurvey: false, isWorking: false, maxRows: 4, bodyColumns: 100,
  scroll: { offset: 0, bodyRows: 40 }, view: {},
}

test('band steps aside until the first status check has run', async ($, on) => {
  on('ui.render', async ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>engine default</Text>
  })
  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ plugin: 'rain-city', surface, component: 'AbovePrompt', props: PROPS })
    expect(await ui.find({ type: 'Text', text: /engine default/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /tailscale/ })).toBeUndefined()
    await ui.unmount()
  }
})
