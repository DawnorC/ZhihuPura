import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const KEY: string = 'queries';
const LIMIT: number = 20;
let pending: Promise<void> = Promise.resolve();

async function readQueries(pref: preferences.Preferences): Promise<string[]> {
  const raw = await pref.get(KEY, '');
  if (typeof raw !== 'string' || raw.length === 0) {
    return [];
  }
  try {
    const entries = JSON.parse(raw) as string[];
    return Array.isArray(entries) ? entries.filter((entry: string): boolean => typeof entry === 'string') : [];
  } catch (error) {
    return [];
  }
}

export async function loadSearchHistory(context: common.Context): Promise<string[]> {
  await pending;
  return readQueries(await preferences.getPreferences(context, 'zhihu_search'));
}

export function updateSearchHistory(context: common.Context, keyword: string): Promise<string[]> {
  const result = pending.then(async (): Promise<string[]> => {
    const pref = await preferences.getPreferences(context, 'zhihu_search');
    const existing = await readQueries(pref);
    const updated = keyword.length === 0 ? [] :
      [keyword].concat(existing.filter((query: string): boolean => query !== keyword)).slice(0, LIMIT);
    await pref.put(KEY, JSON.stringify(updated));
    try {
      await pref.flush();
    } catch (error) {
      await pref.put(KEY, JSON.stringify(existing));
      throw new Error('Unable to save search history');
    }
    return updated;
  });
  pending = result.then((): void => {}).catch((): void => {});
  return result;
}
