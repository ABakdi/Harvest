import { describe, expect, it } from 'vitest';
import {
  HarvestDay,
  commitmentFromRow,
  isDueOn,
  maxUnitsPerDay,
  parseScheduleJson,
  scheduleIsDueOn,
  scheduleToJson,
} from '../src/index.js';

describe('schedules', () => {
  it('round-trips the JSON the phone stores', () => {
    for (const text of [
      '{"type":"daily"}',
      '{"type":"weekly","weekdays":[1,3,5]}',
      '{"type":"interval","everyDays":3,"anchorDay":"2026-09-10"}',
      '{"type":"timesPerWeek","times":4}',
    ]) {
      expect(JSON.stringify(scheduleToJson(parseScheduleJson(text)))).toBe(text);
    }
  });

  it('sorts weekdays as the phone writes them', () => {
    expect(scheduleToJson(parseScheduleJson('{"type":"weekly","weekdays":[5,1,3,1]}'))).toEqual({
      type: 'weekly',
      weekdays: [1, 3, 5],
    });
  });

  it('refuses what the phone would refuse', () => {
    expect(() => parseScheduleJson('{"type":"hourly"}')).toThrow(/unknown schedule type/);
    expect(() => parseScheduleJson('{"type":"interval","everyDays":2}')).toThrow();
    expect(() => parseScheduleJson('{"type":"weekly","weekdays":["mon"]}')).toThrow();
  });

  it('throws on an interval of zero days rather than never being due', () => {
    const schedule = parseScheduleJson('{"type":"interval","everyDays":0,"anchorDay":"2026-09-10"}');
    expect(() => scheduleIsDueOn(schedule, HarvestDay.parse('2026-09-12'))).toThrow(RangeError);
  });
});

describe('seeds', () => {
  const row = {
    type: 'habit',
    createdAt: '2026-09-10T08:00:00.000Z',
    scheduleJson: null,
    totalTarget: null,
    dailyCommitment: null,
    dueDay: null,
    pausedAt: null,
  };

  it('treats a habit with no schedule as daily', () => {
    const habit = commitmentFromRow(row);
    expect(isDueOn(habit, HarvestDay.parse('2026-09-19'))).toBe(true);
  });

  it('reads a synced row', () => {
    const todo = commitmentFromRow({ ...row, type: 'todo', dueDay: '2026-09-21' });
    expect(todo.dueDay?.key).toBe('2026-09-21');
    expect(() => commitmentFromRow({ ...row, type: 'chore' })).toThrow(TypeError);
  });

  it('caps a project at twice its daily commitment and anything else at one', () => {
    expect(maxUnitsPerDay({ type: 'project', dailyCommitment: 15 })).toBe(30);
    expect(maxUnitsPerDay({ type: 'project', dailyCommitment: null })).toBe(0);
    expect(maxUnitsPerDay({ type: 'habit', dailyCommitment: null })).toBe(1);
    expect(maxUnitsPerDay({ type: 'todo', dailyCommitment: 99 })).toBe(1);
  });
});
