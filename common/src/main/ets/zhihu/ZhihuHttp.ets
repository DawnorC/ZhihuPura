/**
 * Zhihu HTTP client: web UA, cookies, x-zse-96 signing, set-cookie capture.
 * Ported from ZhihuApiClients.kt / PaginationViewModel.kt (Ktor-based).
 */
import { http } from '@kit.NetworkKit';
import { rcp } from '@kit.RemoteCommunicationKit';
import { ZhihuSession } from './ZhihuSession';
import { createZse96Header, ZSE_93_WEB } from './ZseSign';

export const ZHIHU_WEB_UA: string =
  'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

export const ZHIHU_QR_UA: string =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36';

export const ZHIHU_APP_UA: string =
  'com.zhihu.android/Futureve/10.61.0 Mozilla/5.0 (Linux; Android 12; sdk_gphone64_arm64 ' +
  'Build/SE1A.220630.001.A1; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/57.0.1000.10 Mobile Safari/537.36';

export const ZHIHU_APP_X_APP_ZA: string =
  'OS=Android&Release=12&Model=sdk_gphone64_arm64&VersionName=10.61.0&VersionCode=26107' +
  '&Product=com.zhihu.android&Width=1440&Height=2952&Installer=%E7%81%B0%E5%BA%A6' +
  '&DeviceType=AndroidPhone&Brand=google';

export class ZhihuHttpError extends Error {
  public readonly status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

export class ZhihuHttpResponse {
  public status: number = 0;
  public text: string = '';
  public location: string = '';
}

export class ZhihuHttp {
  private static readonly instance: ZhihuHttp = new ZhihuHttp();
  private deviceReady: Promise<void> | null = null;

  public static getInstance(): ZhihuHttp {
    return ZhihuHttp.instance;
  }

  private buildHeaders(url: string, body: string | null, sign: boolean, contentType: string,
    session: ZhihuSession): Record<string, string> {
    const headers: Record<string, string> = {};
    headers['User-Agent'] = ZHIHU_WEB_UA;
    headers['Accept'] = '*/*';
    headers['Accept-Language'] = 'zh-CN,zh;q=0.9,en;q=0.8';
    headers['Referer'] = 'https://www.zhihu.com/';
    const cookieHeader = session.cookieHeader();
    if (cookieHeader.length > 0) {
      headers['Cookie'] = cookieHeader;
    }
    if (sign) {
      const dc0 = session.getDc0();
      if (dc0.length > 0) {
        headers['x-zse-93'] = ZSE_93_WEB;
        headers['x-zse-96'] = createZse96Header(ZSE_93_WEB, url, dc0, body);
        headers['x-requested-with'] = 'fetch';
      }
    }
    if (body !== null) {
      headers['Content-Type'] = contentType;
      const xsrf = session.getCookie('_xsrf');
      if (xsrf.length > 0) {
        headers['x-xsrftoken'] = xsrf;
      }
    }
    return headers;
  }

  private captureCookies(headers: Object, session: ZhihuSession): void {
    const headersRecord: Record<string, Object> =
      JSON.parse(JSON.stringify(headers)) as Record<string, Object>;
    const keys = Object.keys(headersRecord);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i].toLowerCase();
      if (key === 'set-cookie') {
        const rawValue = headersRecord[keys[i]];
        if (typeof rawValue === 'string') {
          session.applySetCookieHeader(rawValue);
        } else if (Array.isArray(rawValue)) {
          const lines = rawValue as string[];
          for (let j = 0; j < lines.length; j++) {
            session.applySetCookieHeader(lines[j]);
          }
        }
      }
    }
  }

  private async send(method: http.RequestMethod, url: string, body: string | null, headers: Record<string, string>,
    session: ZhihuSession, timeout: number, maxRedirects?: number): Promise<ZhihuHttpResponse> {
    const client = http.createHttp();
    const revision = session.getRevision();
    const options: http.HttpRequestOptions = {
      method: method,
      header: headers,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: Math.min(15000, timeout),
      readTimeout: timeout,
      usingCache: false,
      maxRedirects
    };
    if (body !== null) {
      options.extraData = body;
    }
    try {
      const response = await client.request(url, options);
      if (session.getRevision() === revision) {
        this.captureCookies(response.header, session);
      }
      const result = new ZhihuHttpResponse();
      result.status = response.responseCode;
      result.text = typeof response.result === 'string' ? response.result : '';
      return result;
    } catch (error) {
      throw new ZhihuHttpError(-1, (error as Error).message);
    } finally {
      client.destroy();
    }
  }

  private async sendLogin(method: http.RequestMethod, url: string, body: string | null,
    headers: Record<string, string>, session: ZhihuSession): Promise<ZhihuHttpResponse> {
    // Keep redirects visible and prevent guest or account credentials from being forwarded automatically.
    const client = rcp.createSession({
      requestConfiguration: { transfer: { autoRedirect: false, timeout: { connectMs: 8000, transferMs: 12000 } } }
    });
    const revision = session.getRevision();
    try {
      const response = await client.fetch(new rcp.Request(url, method, headers, body ?? undefined));
      if (session.getRevision() === revision) {
        this.captureCookies(response.headers, session);
      }
      const result = new ZhihuHttpResponse();
      result.status = response.statusCode;
      result.text = response.toString() ?? '';
      const responseHeaders = response.headers as Record<string, string | string[] | undefined>;
      const locationKey = Object.keys(responseHeaders).find((name: string): boolean => name.toLowerCase() === 'location');
      const location = locationKey ? responseHeaders[locationKey] : undefined;
      result.location = typeof location === 'string' ? location : location?.[0] ?? '';
      return result;
    } catch (error) {
      throw new ZhihuHttpError(-1, '连接知乎失败，请重试');
    } finally {
      client.close();
    }
  }

  public async request(method: http.RequestMethod, url: string, body: string | null, sign: boolean,
    contentType: string = 'application/json'): Promise<ZhihuHttpResponse> {
    const session = ZhihuSession.getInstance();
    const headers = this.buildHeaders(url, body, sign, contentType, session);
    const response = await this.send(method, url, body, headers, session, 20000);
    if (response.status >= 400) {
      throw new ZhihuHttpError(response.status, 'HTTP ' + response.status + ' ' + response.text.substring(0, 200));
    }
    return response;
  }

  public requestForLogin(method: http.RequestMethod, path: string, session: ZhihuSession,
    body: string | null = null, sign: boolean = false): Promise<ZhihuHttpResponse> {
    if (!/^\/(?!\/)[^\\\r\n]*$/.test(path)) {
      return Promise.reject(new Error('知乎登录地址无效'));
    }
    const origin = 'https://www.zhihu.com';
    const url = origin + path;
    const headers = this.buildHeaders(url, body, sign, 'application/json;charset=UTF-8', session);
    headers['User-Agent'] = ZHIHU_QR_UA;
    headers['Accept'] = 'application/json, text/plain, */*';
    headers['Accept-Language'] = 'en-US,en;q=0.9';
    headers['sec-ch-ua'] = '"Not:A-Brand";v="99", "Google Chrome";v="145", "Chromium";v="145"';
    headers['sec-ch-ua-mobile'] = '?0';
    headers['sec-ch-ua-platform'] = '"Windows"';
    if (/^\/(?:signin|signup|account\/(?:risk_control|unhuman))(?:[/?]|$)/.test(path)) {
      return this.sendLogin(method, url, body, headers, session);
    }
    headers['Referer'] = origin + '/signin';
    headers['Origin'] = origin;
    headers['x-requested-with'] = 'fetch';
    headers['Content-Type'] = 'application/json;charset=UTF-8';
    if (session.hasCookie('_xsrf')) {
      headers['x-xsrftoken'] = session.getCookie('_xsrf');
    }
    if (path.endsWith('/scan_info')) {
      headers['Accept'] = '*/*';
      headers['Referer'] = origin + '/signin?next=%2F';
      headers['sec-fetch-dest'] = 'empty';
      headers['sec-fetch-mode'] = 'cors';
      headers['sec-fetch-site'] = 'same-origin';
      headers['x-zse-93'] = ZSE_93_WEB;
    }
    return this.sendLogin(method, url, body, headers, session);
  }

  public requestForPhoneLogin(method: http.RequestMethod, path: string, headers: Record<string, string>,
    session: ZhihuSession, body: string | null = null): Promise<ZhihuHttpResponse> {
    if (!/^\/(?:captcha|api\/account\/prod\/(?:init\/udid_guest|auth\/digits|sign_in))$/.test(path)) {
      return Promise.reject(new Error('知乎手机号登录地址无效'));
    }
    return this.sendLogin(method, 'https://api.zhihu.com' + path, body, headers, session);
  }

  public get(url: string, sign: boolean): Promise<ZhihuHttpResponse> {
    return this.request(http.RequestMethod.GET, url, null, sign);
  }

  /** Mobile recommendations use the current session and the upstream mobile request headers. */
  public async appGet(url: string): Promise<ZhihuHttpResponse> {
    const target = url.replace(/^http:\/\/api\.zhihu\.com\//, 'https://api.zhihu.com/');
    if (!/^https:\/\/api\.zhihu\.com\/topstory\/recommend(?:\?[^#\\\s]*)?$/.test(target)) {
      throw new Error('推荐分页地址无效');
    }
    const session = ZhihuSession.getInstance();
    const headers: Record<string, string> = {};
    headers['User-Agent'] = ZHIHU_APP_UA;
    headers['x-api-version'] = '3.1.8';
    headers['x-app-version'] = '10.61.0';
    headers['x-app-za'] = ZHIHU_APP_X_APP_ZA;
    const cookies = session.cookieHeader();
    if (cookies) {
      headers['Cookie'] = cookies;
    }
    const response = await this.send(http.RequestMethod.GET, target, null, headers, session, 20000, 0);
    if (response.status < 200 || response.status >= 300) {
      throw new ZhihuHttpError(response.status, 'HTTP ' + response.status);
    }
    return response;
  }

  public post(url: string, body: string | null, sign: boolean): Promise<ZhihuHttpResponse> {
    return this.request(http.RequestMethod.POST, url, body, sign);
  }

  public delete(url: string, sign: boolean): Promise<ZhihuHttpResponse> {
    return this.request(http.RequestMethod.DELETE, url, null, sign);
  }

  public putForm(url: string, body: string): Promise<ZhihuHttpResponse> {
    return this.request(http.RequestMethod.PUT, url, body, false, 'application/x-www-form-urlencoded');
  }

  /**
   * Web device warm-up: obtains d_c0 from https://www.zhihu.com/udid (as the Android app does).
   */
  public ensureDevice(): Promise<void> {
    const session = ZhihuSession.getInstance();
    if (session.getDc0().length > 0) {
      return Promise.resolve();
    }
    if (this.deviceReady === null) {
      this.deviceReady = this.post('https://www.zhihu.com/udid', null, false)
        .then(async (): Promise<void> => {
          await session.persist();
        })
        .finally((): void => {
          this.deviceReady = null;
        });
    }
    return this.deviceReady;
  }
}
