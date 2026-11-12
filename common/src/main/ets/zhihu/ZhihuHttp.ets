/**
 * Zhihu HTTP client: web UA, cookies, x-zse-96 signing, set-cookie capture.
 * Ported from ZhihuApiClients.kt / PaginationViewModel.kt (Ktor-based).
 */
import { http } from '@kit.NetworkKit';
import { ZhihuSession } from './ZhihuSession';
import { createZse96Header, ZSE_93_WEB } from './ZseSign';

export const ZHIHU_WEB_UA: string =
  'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

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
}

export class ZhihuHttp {
  private static readonly instance: ZhihuHttp = new ZhihuHttp();
  private deviceReady: Promise<void> | null = null;

  public static getInstance(): ZhihuHttp {
    return ZhihuHttp.instance;
  }

  private buildHeaders(url: string, body: string | null, sign: boolean): Record<string, string> {
    const session = ZhihuSession.getInstance();
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
      headers['Content-Type'] = 'application/json';
      const xsrf = session.getCookie('_xsrf');
      if (xsrf.length > 0) {
        headers['x-xsrftoken'] = xsrf;
      }
    }
    return headers;
  }

  private captureCookies(response: http.HttpResponse): void {
    const session = ZhihuSession.getInstance();
    const headersRecord: Record<string, Object> =
      JSON.parse(JSON.stringify(response.header)) as Record<string, Object>;
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

  public request(method: http.RequestMethod, url: string, body: string | null, sign: boolean): Promise<ZhihuHttpResponse> {
    const client = http.createHttp();
    const headers = this.buildHeaders(url, body, sign);
    const options: http.HttpRequestOptions = {
      method: method,
      header: headers,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 15000,
      readTimeout: 20000,
      usingCache: false
    };
    if (body !== null) {
      options.extraData = body;
    }
    return client.request(url, options).then((response: http.HttpResponse) => {
      this.captureCookies(response);
      const result = new ZhihuHttpResponse();
      result.status = response.responseCode;
      if (typeof response.result === 'string') {
        result.text = response.result;
      } else {
        result.text = '';
      }
      client.destroy();
      if (response.responseCode >= 400) {
        throw new ZhihuHttpError(response.responseCode,
          'HTTP ' + response.responseCode + ' ' + result.text.substring(0, 200));
      }
      return result;
    }).catch((error: Error) => {
      client.destroy();
      if (error instanceof ZhihuHttpError) {
        throw error;
      }
      throw new ZhihuHttpError(-1, error.message);
    });
  }

  public get(url: string, sign: boolean): Promise<ZhihuHttpResponse> {
    return this.request(http.RequestMethod.GET, url, null, sign);
  }

  /**
   * Official-app-profile GET (api.zhihu.com mobile endpoints):
   * app UA + x-api-version/x-app-version/x-app-za, no cookies, no x-zse-96 signing.
   * Mirrors mobileHomeFeedHttpClient() in AndroidPaginationEnvironment.android.kt.
   */
  public appGet(url: string): Promise<ZhihuHttpResponse> {
    const client = http.createHttp();
    const headers: Record<string, string> = {};
    headers['User-Agent'] = ZHIHU_APP_UA;
    headers['x-api-version'] = '3.1.8';
    headers['x-app-version'] = '10.61.0';
    headers['x-app-za'] = ZHIHU_APP_X_APP_ZA;
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      header: headers,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 15000,
      readTimeout: 20000,
      usingCache: false
    };
    return client.request(url, options).then((response: http.HttpResponse) => {
      this.captureCookies(response);
      const result = new ZhihuHttpResponse();
      result.status = response.responseCode;
      if (typeof response.result === 'string') {
        result.text = response.result;
      } else {
        result.text = '';
      }
      client.destroy();
      if (response.responseCode >= 400) {
        throw new ZhihuHttpError(response.responseCode,
          'HTTP ' + response.responseCode + ' ' + result.text.substring(0, 200));
      }
      return result;
    }).catch((error: Error) => {
      client.destroy();
      if (error instanceof ZhihuHttpError) {
        throw error;
      }
      throw new ZhihuHttpError(-1, error.message);
    });
  }

  public post(url: string, body: string | null, sign: boolean): Promise<ZhihuHttpResponse> {
    return this.request(http.RequestMethod.POST, url, body, sign);
  }

  public delete(url: string, sign: boolean): Promise<ZhihuHttpResponse> {
    return this.request(http.RequestMethod.DELETE, url, null, sign);
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
        .catch(async (error: Error): Promise<void> => {
          this.deviceReady = null;
          throw error;
        });
    }
    return this.deviceReady;
  }
}
