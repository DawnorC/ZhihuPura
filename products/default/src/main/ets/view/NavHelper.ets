/**
 * Navigation helpers: route params, open item routing, cookie sync to WebView.
 */
import { ZhihuContentType, ZhihuFeedItem, ZhihuSession } from '@ohos/common';
import { webview } from '@kit.ArkWeb';
import { pasteboard } from '@kit.BasicServicesKit';
import { common, Want } from '@kit.AbilityKit';
import { UIContext } from '@kit.ArkUI';

export interface ContentPageParam {
  kind: string;
  id: string;
  title: string;
  questionId?: string;
  answerIds?: string[];
  nextAnswerPage?: string;
  answerListEnd?: boolean;
  answerOrder?: string;
}

export interface QuestionPageParam {
  id: string;
}

export interface CommentsPageParam {
  kind: string;
  id: string;
  title: string;
}

export interface PeoplePageParam {
  urlToken: string;
}

export interface DailyStoryPageParam {
  id: string;
}

export interface WebPageParam {
  url: string;
  title: string;
}

export const APP_COLOR_BLUE: string = '#0066FF';
export const APP_COLOR_BG: string = '#F5F6F7';
export const APP_COLOR_CARD: string = '#FFFFFF';
export const APP_COLOR_TEXT: string = '#1A1A1A';
export const APP_COLOR_SECONDARY: string = '#8590A6';
export const APP_COLOR_DIVIDER: string = '#F0F0F0';

export function contentKindOf(item: ZhihuFeedItem): string {
  if (item.contentType === ZhihuContentType.Answer) {
    return 'answers';
  }
  if (item.contentType === ZhihuContentType.Article) {
    return 'articles';
  }
  if (item.contentType === ZhihuContentType.Pin) {
    return 'pins';
  }
  return 'questions';
}

export function syncCookiesToWebView(): void {
  const session = ZhihuSession.getInstance();
  try {
    const keys: string[] = ['z_c0', 'd_c0', '_xsrf', 'BEC', 'SESSIONID', 'captcha_ticket_v3', 'JOID', 'gdxidpybxdE'];
    for (let i = 0; i < keys.length; i++) {
      const value = session.getCookie(keys[i]);
      if (value.length > 0) {
        const attributes = '; Domain=.zhihu.com; Path=/; Secure' + (keys[i] === 'z_c0' ? '; HttpOnly' : '');
        const cookie = keys[i] + '=' + value + attributes;
        webview.WebCookieManager.configCookieSync('https://www.zhihu.com', cookie, false, true);
        webview.WebCookieManager.configCookieSync('https://api.zhihu.com', cookie, false, true);
      }
    }
    webview.WebCookieManager.saveCookieSync();
  } catch (error) {
    // WebView cookie sync is best-effort
  }
}

export function clearZhihuWebLogin(): void {
  try {
    const expired = 'z_c0=; Path=/; Max-Age=0; Secure; HttpOnly';
    const origins: string[] = ['https://www.zhihu.com', 'https://api.zhihu.com'];
    for (const origin of origins) {
      webview.WebCookieManager.configCookieSync(origin, expired, false, true);
      webview.WebCookieManager.configCookieSync(origin, expired + '; Domain=.zhihu.com', false, true);
    }
    webview.WebCookieManager.saveCookieSync();
  } catch (error) {
    // The native session has already been removed.
  }
}

export function openFeedItem(stack: NavPathStack, item: ZhihuFeedItem): void {
  if (item.contentType === ZhihuContentType.Answer) {
    const param: ContentPageParam = { kind: 'answer', id: item.id, title: item.title, questionId: item.questionId };
    stack.pushPathByName('content', param);
    return;
  }
  if (item.contentType === ZhihuContentType.Article) {
    const param: ContentPageParam = { kind: 'article', id: item.id, title: item.title };
    stack.pushPathByName('content', param);
    return;
  }
  if (item.contentType === ZhihuContentType.Pin) {
    const param: ContentPageParam = { kind: 'pin', id: item.id, title: '想法' };
    stack.pushPathByName('content', param);
    return;
  }
  if (item.contentType === ZhihuContentType.Video) {
    const param: WebPageParam = { url: 'https://www.zhihu.com/zvideo/' + item.id, title: item.title };
    stack.pushPathByName('web', param);
    return;
  }
  if (item.contentType === ZhihuContentType.People) {
    const param: PeoplePageParam = { urlToken: item.authorToken };
    stack.pushPathByName('people', param);
    return;
  }
  if (item.contentType === ZhihuContentType.Question) {
    const id = item.questionId.length > 0 ? item.questionId : item.id;
    const param: QuestionPageParam = { id: id };
    stack.pushPathByName('question', param);
    return;
  }
}

export function showToast(context: UIContext, message: string): void {
  try {
    context.getPromptAction().showToast({ message: message, duration: 2000 });
  } catch (error) {
    // toast is best-effort
  }
}

export function copyToClipboard(context: UIContext, text: string): void {
  const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
  pasteboard.getSystemPasteboard().setData(data)
    .then((): void => {
      showToast(context, '已复制到剪贴板');
    })
    .catch((): void => {
      showToast(context, '复制失败');
    });
}

export function openInBrowser(context: common.Context, url: string): void {
  try {
    const abilityContext = context as common.UIAbilityContext;
    const want: Want = {
      action: 'ohos.want.action.viewData',
      uri: url,
      type: 'text/html',
      entities: ['entity.system.browsable']
    };
    abilityContext.startAbility(want).catch((): void => {
    });
  } catch (error) {
    // opening external browser is best-effort
  }
}
