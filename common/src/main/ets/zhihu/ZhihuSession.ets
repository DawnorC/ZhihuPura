/**
 * Zhihu session: cookie jar + current user, persisted with preferences.
 * Ported from ZhihuAccountRepository / ZhihuAccountSession (Kotlin).
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export class ZhihuUser {
  id: string = '';
  name: string = '';
  avatarUrl: string = '';
  urlToken: string = '';
  headline: string = '';
}

interface IUserRaw {
  id?: string;
  name?: string;
  avatar_url?: string;
  avatar_url_template?: string;
  url_token?: string;
  headline?: string;
}

export class ZhihuSession {
  private static readonly instance: ZhihuSession = new ZhihuSession();
  private pref: preferences.Preferences | null = null;
  private cookieMap: Record<string, string> = {};
  readonly user: ZhihuUser = new ZhihuUser();
  private initPromise: Promise<void> | null = null;

  public static getInstance(): ZhihuSession {
    return ZhihuSession.instance;
  }

  public init(context: common.Context): Promise<void> {
    if (this.initPromise === null) {
      this.initPromise = this.doInit(context);
    }
    return this.initPromise;
  }

  private async doInit(context: common.Context): Promise<void> {
    this.pref = await preferences.getPreferences(context, 'zhihu_session');
    const cookieJson = await this.pref.get('cookies', '');
    if (typeof cookieJson === 'string' && cookieJson.length > 0) {
      try {
        this.cookieMap = JSON.parse(cookieJson) as Record<string, string>;
      } catch (error) {
        this.cookieMap = {};
      }
    }
    const userJson = await this.pref.get('user', '');
    if (typeof userJson === 'string' && userJson.length > 0) {
      try {
        const raw = JSON.parse(userJson) as IUserRaw;
        this.user.id = raw.id ?? '';
        this.user.name = raw.name ?? '';
        this.user.avatarUrl = raw.avatar_url ?? '';
        this.user.urlToken = raw.url_token ?? '';
        this.user.headline = raw.headline ?? '';
      } catch (error) {
        // ignore malformed user cache
      }
    }
  }

  public async persist(): Promise<void> {
    if (this.pref === null) {
      return;
    }
    await this.pref.put('cookies', JSON.stringify(this.cookieMap));
    const userRaw: IUserRaw = {
      id: this.user.id,
      name: this.user.name,
      avatar_url: this.user.avatarUrl,
      url_token: this.user.urlToken,
      headline: this.user.headline
    };
    await this.pref.put('user', JSON.stringify(userRaw));
    await this.pref.flush();
  }

  public getCookie(name: string): string {
    const value = this.cookieMap[name];
    return value ?? '';
  }

  public hasCookie(name: string): boolean {
    return this.getCookie(name).length > 0;
  }

  public setCookie(name: string, value: string): void {
    this.cookieMap[name] = value;
  }

  public removeCookie(name: string): void {
    this.cookieMap[name] = '';
  }

  public cookieHeader(): string {
    const parts: string[] = [];
    const keys = Object.keys(this.cookieMap);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const value = this.cookieMap[key];
      if (value.length > 0) {
        parts.push(key + '=' + value);
      }
    }
    return parts.join('; ');
  }

  public allCookies(): string {
    return this.cookieHeader();
  }

  public applyCookieString(cookieString: string): void {
    if (cookieString.length === 0) {
      return;
    }
    const segments = cookieString.split(';');
    for (let i = 0; i < segments.length; i++) {
      const segment = segments[i].trim();
      const eqIndex = segment.indexOf('=');
      if (eqIndex > 0) {
        const name = segment.substring(0, eqIndex).trim();
        const value = segment.substring(eqIndex + 1).trim();
        if (name.length > 0 && value.length > 0) {
          this.cookieMap[name] = value;
        }
      }
    }
  }

  public applySetCookieHeader(headerValue: string): void {
    if (headerValue.length === 0) {
      return;
    }
    const rawLines = headerValue.split(/,(?=\s*[^;=\s]+=)/);
    for (let i = 0; i < rawLines.length; i++) {
      const pair = rawLines[i].split(';')[0];
      const eqIndex = pair.indexOf('=');
      if (eqIndex > 0) {
        const name = pair.substring(0, eqIndex).trim();
        let value = pair.substring(eqIndex + 1).trim();
        if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
          value = value.substring(1, value.length - 1);
        }
        if (name.length === 0) {
          continue;
        }
        if (name === 'z_c0' && value.length === 0) {
          continue;
        }
        this.cookieMap[name] = value;
      }
    }
  }

  public getDc0(): string {
    return this.getCookie('d_c0');
  }

  public isLoggedIn(): boolean {
    const zc0 = this.getCookie('z_c0');
    return zc0.length > 1;
  }

  public async logout(): Promise<void> {
    this.cookieMap = {};
    this.user.id = '';
    this.user.name = '';
    this.user.avatarUrl = '';
    this.user.urlToken = '';
    this.user.headline = '';
    await this.persist();
  }
}
