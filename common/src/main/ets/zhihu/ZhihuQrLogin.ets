import { http } from '@kit.NetworkKit';
import { ZhihuHttp, ZhihuHttpError, ZhihuHttpResponse } from './ZhihuHttp';
import { ZhihuSession } from './ZhihuSession';

const ZHIHU_ORIGIN: string = 'https://www.zhihu.com';
const QR_PATH: string = '/api/v3/account/api/login/qrcode';
const SIGN_IN_PATH: string = '/signin?next=%2F';
export const ZHIHU_RISK_CONTROL_URL: string = ZHIHU_ORIGIN + '/account/risk_control/';
const DEFAULT_TTL: number = 120000;

export function isZhihuLoginPage(url: string): boolean {
  return /^https:\/\/(?:www\.)?zhihu\.com(?::443)?(?:[/?#]|$)/i.test(url) && !/[\\\s]/.test(url);
}

export function isZhihuVerificationPage(url: string): boolean {
  return isZhihuLoginPage(url) &&
    /^https:\/\/(?:www\.)?zhihu\.com(?::443)?\/account\/(?:risk_control|unhuman)(?:[/?#]|$)/i.test(url);
}

export enum ZhihuQrLoginStatus {
  Waiting,
  Scanned,
  Confirmed,
  Expired
}

export interface ZhihuQrTicket {
  link: string;
  token: string;
  deadline: number;
}

export class ZhihuLoginVerificationError extends Error {
  readonly verificationUrl: string;

  constructor(url: string) {
    super('知乎要求完成安全验证');
    this.verificationUrl = url;
  }
}

interface QrErrorReply {
  code?: number;
  redirect?: string;
}

interface QrReply {
  link?: string;
  token?: string;
  qrcode_token?: string;
  qrcodeToken?: string;
  expires_at?: number;
  expiresAt?: number;
  status?: number;
  login_status?: string;
  loginStatus?: string;
  success?: boolean;
  logged_in?: boolean;
  loggedIn?: boolean;
  user_id?: string | number;
  userId?: string | number;
  access_token?: string;
  accessToken?: string;
  cookie?: string;
  cookies?: string;
  z_c0?: string;
  zC0?: string;
  error?: QrErrorReply;
}

function qrDeadline(value: number | undefined): number {
  const now = Date.now();
  if (value === undefined || !Number.isFinite(value) || value <= 0) {
    return now + DEFAULT_TTL;
  }
  if (value <= 86400) {
    return now + value * 1000;
  }
  if (value <= 86400000) {
    return now + value;
  }
  const timestamp = value < 10000000000 ? value * 1000 : value;
  return timestamp < now - 86400000 ? now + DEFAULT_TTL : timestamp;
}

function verificationUrl(value?: string): string {
  if (typeof value === 'string') {
    const url = /^\/(?!\/)/.test(value) ? ZHIHU_ORIGIN + value : value;
    if (isZhihuVerificationPage(url)) {
      return url;
    }
  }
  return '';
}

function checkResponse(response: ZhihuHttpResponse): QrReply | undefined {
  let data: QrReply | undefined;
  try {
    const json = JSON.parse(response.text) as QrReply;
    if (json && typeof json === 'object' && !Array.isArray(json)) {
      data = json;
    }
  } catch (error) {
    // The initial sign-in page is HTML.
  }
  const redirect = verificationUrl(response.location) || verificationUrl(data?.error?.redirect);
  if (redirect || response.status === 403 || Number(data?.error?.code) === 40352) {
    throw new ZhihuLoginVerificationError(redirect || ZHIHU_RISK_CONTROL_URL);
  }
  if (response.status === 429) {
    throw new Error('请求较频繁，请稍后重试');
  }
  if (response.status < 200 || response.status >= 300 || data?.error?.code) {
    throw new Error('知乎扫码登录请求失败（HTTP ' + response.status + '）');
  }
  return data;
}

/**
 * The upstream QR flow uses a temporary Zhihu web session. The app adopts its
 * cookies only after the account endpoint verifies them.
 */
export class ZhihuQrLogin {
  private readonly httpClient: ZhihuHttp = ZhihuHttp.getInstance();
  private readonly session: ZhihuSession = new ZhihuSession();
  private lastConfirmationCheck: number = 0;
  private closed: boolean = false;

  constructor(cookies: string = '') {
    this.session.applyCookieString(cookies);
    this.session.removeCookie('z_c0');
  }

  public close(): void {
    this.closed = true;
  }

  public cookieHeader(): string {
    return this.session.cookieHeader();
  }

  private async request(method: http.RequestMethod, path: string, body: string | null = null): Promise<ZhihuHttpResponse> {
    if (this.closed) {
      throw new Error('扫码已取消');
    }
    const response = await this.httpClient.requestForLogin(method, path, this.session, body);
    if (this.closed) {
      throw new Error('扫码已取消');
    }
    return response;
  }

  private async prefetchSignIn(): Promise<void> {
    let path = SIGN_IN_PATH;
    let challenge = '';
    for (let attempt = 0; attempt < 3; attempt++) {
      const response = await this.request(http.RequestMethod.GET, path);
      const location = response.location.replace(/^https:\/\/www\.zhihu\.com(?::443)?/i, '');
      const challengeLocation = /^\/(?!\/)/.test(location) ? verificationUrl(location) : '';
      // Follow the sign-in document's same-origin redirects as the upstream client does. The API
      // requests below still stop on their own verification responses.
      if (response.status >= 300 && response.status < 400 && location !== path &&
        (/^\/(?:signin|signup)(?:\?[^/\\\s]*)?$/.test(location) || challengeLocation)) {
        challenge = challengeLocation || challenge;
        path = location;
      } else {
        if (response.status === 403 && challenge) {
          throw new ZhihuLoginVerificationError(challenge);
        }
        checkResponse(response);
        return;
      }
    }
    if (challenge) {
      throw new ZhihuLoginVerificationError(challenge);
    }
    throw new Error('知乎登录地址重定向次数过多，请重试');
  }

  private async prefetchEndpoint(method: http.RequestMethod, path: string, body: string | null = null): Promise<void> {
    try {
      checkResponse(await this.request(method, path, body));
    } catch (error) {
      if (!(error instanceof ZhihuHttpError) || error.status !== -1) {
        throw error as Error;
      }
    }
  }

  public async createTicket(): Promise<ZhihuQrTicket> {
    await this.prefetchSignIn();
    await this.prefetchEndpoint(http.RequestMethod.POST, '/udid', '{}');
    await this.prefetchEndpoint(http.RequestMethod.GET, '/api/v3/oauth/captcha/v2?type=captcha_sign_in');
    const data = checkResponse(await this.request(http.RequestMethod.POST, QR_PATH, '{}'));
    const token = data?.token ?? data?.qrcode_token ?? data?.qrcodeToken;
    const link = data?.link;
    if (typeof token !== 'string' || token.trim().length === 0 || token.length > 512 ||
      typeof link !== 'string' || link.length > 512 ||
      !(isZhihuLoginPage(link) || /^zhihu:\/\/[^\\\s]+$/i.test(link))) {
      throw new Error('知乎未返回可用的二维码，请重试');
    }
    return { link, token, deadline: qrDeadline(data?.expires_at ?? data?.expiresAt) };
  }

  public async poll(ticket: ZhihuQrTicket): Promise<ZhihuQrLoginStatus> {
    if (Date.now() >= ticket.deadline) {
      return ZhihuQrLoginStatus.Expired;
    }
    const path = QR_PATH + '/' + encodeURIComponent(ticket.token) + '/scan_info';
    const response = await this.request(http.RequestMethod.GET, path);
    if (response.status === 404 || response.status === 410) {
      return ZhihuQrLoginStatus.Expired;
    }
    const data = checkResponse(response);
    if (!data) {
      throw new Error('知乎扫码状态响应异常，请重试');
    }
    const rawStatus = data.login_status ?? data.loginStatus;
    const status = typeof rawStatus === 'string' ? rawStatus.toUpperCase() : '';
    if (data.status === 2 || ['EXPIRED', 'QR_CODE_EXPIRED', 'LOGIN_EXPIRED'].includes(status)) {
      return ZhihuQrLoginStatus.Expired;
    }

    if (typeof data.cookie === 'string') {
      this.session.applyCookieString(data.cookie);
    }
    if (typeof data.cookies === 'string') {
      this.session.applyCookieString(data.cookies);
    }
    const sessionCookie = data.z_c0 ?? data.zC0;
    if (typeof sessionCookie === 'string') {
      this.session.applyCookieString('z_c0=' + sessionCookie);
    }

    const confirmed = data.success === true || data.logged_in === true || data.loggedIn === true ||
      !!(data.user_id ?? data.userId) || !!(data.access_token ?? data.accessToken) ||
      ['CONFIRMED', 'LOGIN_SUCCESS', 'SUCCESS', 'OK', 'LOGGED_IN'].includes(status);
    if (confirmed && !this.session.isLoggedIn() && Date.now() - this.lastConfirmationCheck >= 3000) {
      this.lastConfirmationCheck = Date.now();
      const account = await this.request(http.RequestMethod.GET, '/api/v4/me');
      if (account.status === 403 || account.status === 429 || (account.status >= 300 && account.status < 400)) {
        checkResponse(account);
      }
    }
    if (this.session.isLoggedIn()) {
      return ZhihuQrLoginStatus.Confirmed;
    }
    return data.status === 1 || confirmed ? ZhihuQrLoginStatus.Scanned : ZhihuQrLoginStatus.Waiting;
  }
}
