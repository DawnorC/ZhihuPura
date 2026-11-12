/**
 * Blocked-word store (屏蔽词), ported from the Android app's blocklist feature.
 * Supports plain substring matching and best-effort regex matching.
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export class BlockStore {
  private static readonly instance: BlockStore = new BlockStore();
  private pref: preferences.Preferences | null = null;
  private words: string[] = [];
  private initPromise: Promise<void> | null = null;

  public static getInstance(): BlockStore {
    return BlockStore.instance;
  }

  public init(context: common.Context): Promise<void> {
    if (this.initPromise === null) {
      this.initPromise = this.doInit(context);
    }
    return this.initPromise;
  }

  private async doInit(context: common.Context): Promise<void> {
    this.pref = await preferences.getPreferences(context, 'zhihu_settings');
    const raw = await this.pref.get('blocked_words', '');
    if (typeof raw === 'string' && raw.length > 0) {
      try {
        this.words = JSON.parse(raw) as string[];
      } catch (error) {
        this.words = [];
      }
    }
  }

  public async persist(): Promise<void> {
    if (this.pref === null) {
      return;
    }
    await this.pref.put('blocked_words', JSON.stringify(this.words));
    await this.pref.flush();
  }

  public getWords(): string[] {
    return this.words.slice();
  }

  public hasWord(word: string): boolean {
    return this.words.indexOf(word) >= 0;
  }

  public async addWord(word: string): Promise<void> {
    const trimmed = word.trim();
    if (trimmed.length === 0 || this.hasWord(trimmed)) {
      return;
    }
    this.words.push(trimmed);
    await this.persist();
  }

  public async removeWord(word: string): Promise<void> {
    const index = this.words.indexOf(word);
    if (index >= 0) {
      this.words.splice(index, 1);
      await this.persist();
    }
  }

  private matchesWord(word: string, text: string): boolean {
    if (word.length === 0 || text.length === 0) {
      return false;
    }
    if (text.toLowerCase().indexOf(word.toLowerCase()) >= 0) {
      return true;
    }
    try {
      const pattern = new RegExp(word, 'i');
      return pattern.test(text);
    } catch (error) {
      return false;
    }
  }

  public isBlocked(title: string, summary: string): boolean {
    for (let i = 0; i < this.words.length; i++) {
      if (this.matchesWord(this.words[i], title) || this.matchesWord(this.words[i], summary)) {
        return true;
      }
    }
    return false;
  }
}
