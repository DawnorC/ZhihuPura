import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export interface HistoryEntry {
  kind: string;
  id: string;
  title: string;
  viewedAt: number;
}

const HISTORY_LIMIT: number = 200;

export class HistoryStore {
  private static readonly instance: HistoryStore = new HistoryStore();
  private pending: Promise<void> = Promise.resolve();

  public static getInstance(): HistoryStore {
    return HistoryStore.instance;
  }

  private async read(pref: preferences.Preferences): Promise<HistoryEntry[]> {
    const raw = await pref.get('entries', '');
    if (typeof raw !== 'string' || raw.length === 0) {
      return [];
    }
    try {
      const entries = JSON.parse(raw) as HistoryEntry[];
      return Array.isArray(entries) ? entries : [];
    } catch (error) {
      return [];
    }
  }

  public async list(context: common.Context): Promise<HistoryEntry[]> {
    await this.pending;
    return this.read(await preferences.getPreferences(context, 'zhihu_history'));
  }

  private update(context: common.Context, kind: string, id: string, entry: HistoryEntry | null): Promise<void> {
    const update = this.pending.then(async (): Promise<void> => {
      const pref = await preferences.getPreferences(context, 'zhihu_history');
      const entries = await this.read(pref);
      const updated = entries.filter((item: HistoryEntry): boolean => item.kind !== kind || item.id !== id);
      if (entry !== null) {
        updated.unshift(entry);
      }
      await pref.put('entries', JSON.stringify(updated.slice(0, HISTORY_LIMIT)));
      try {
        await pref.flush();
      } catch (error) {
        await pref.put('entries', JSON.stringify(entries));
        throw new Error('Unable to save browsing history');
      }
    });
    this.pending = update.catch((): void => {});
    return update;
  }

  public record(context: common.Context, kind: string, id: string, title: string): Promise<void> {
    if (id.length === 0) {
      return Promise.resolve();
    }
    const entry: HistoryEntry = { kind, id, title, viewedAt: Math.floor(Date.now() / 1000) };
    return this.update(context, kind, id, entry);
  }

  public remove(context: common.Context, entry: HistoryEntry): Promise<void> {
    return this.update(context, entry.kind, entry.id, null);
  }
}
