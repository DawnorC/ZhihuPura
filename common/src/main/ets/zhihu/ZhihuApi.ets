/**
 * Zhihu API endpoints, ported from ZhihuApiClients / viewmodels (Kotlin).
 */
import { ZhihuHttp, ZhihuHttpResponse } from './ZhihuHttp';
import { ZhihuSession } from './ZhihuSession';
import { http } from '@kit.NetworkKit';
import { ZhihuContentType } from './ZhihuContentType';
import {
  ZhihuFeedPage,
  ZhihuCommentPage,
  ZhihuContent,
  ZhihuQuestion,
  ZhihuPerson,
  ZhihuDailySection,
  ZhihuDailyDetail,
  OnlineHistoryEntry,
  OnlineHistoryPage,
  ZhihuCollectionPage,
  IRawPerson,
  IRawTarget,
  parseFeedResponse,
  parseMobileHomeFeedResponse,
  parseHotListResponse,
  parseContentListResponse,
  parseSearchResponse,
  parseCommentsResponse,
  parseDailyResponse,
  parseDailyDetail,
  parseOnlineHistory,
  parseCollections,
  parseCollectionItems,
  buildPinHtml,
  stripHtml,
  formatCount
} from './ZhihuModels';

export interface ZhihuSearchFilters {
  type: string;
  sort: string;
  time: string;
}

interface HotSearchResponse {
  hot_search_queries?: HotSearchEntry[];
}

interface HotSearchEntry {
  query?: string;
}

interface OnlineHistoryPair {
  content_token: string;
  content_type: string;
}

interface DeleteOnlineHistoryRequest {
  pairs: OnlineHistoryPair[];
  clear: boolean;
}

export class ZhihuApi {
  private static readonly instance: ZhihuApi = new ZhihuApi();
  private readonly http: ZhihuHttp = ZhihuHttp.getInstance();
  private readonly session: ZhihuSession = ZhihuSession.getInstance();

  public static getInstance(): ZhihuApi {
    return ZhihuApi.instance;
  }

  private async signedGet(url: string): Promise<string> {
    await this.http.ensureDevice();
    const response = await this.http.get(url, true);
    return response.text;
  }

  public fetchRecommend(url: string | null): Promise<ZhihuFeedPage> {
    const targetUrl = url !== null && url.length > 0 ? url : 'https://api.zhihu.com/topstory/recommend';
    return this.http.appGet(targetUrl).then((response: ZhihuHttpResponse): ZhihuFeedPage =>
      parseMobileHomeFeedResponse(response.text));
  }

  public fetchHotList(url: string | null): Promise<ZhihuFeedPage> {
    const targetUrl = url !== null && url.length > 0 ? url :
      'https://www.zhihu.com/api/v3/feed/topstory/hot-lists/total?limit=50&mobile=true';
    return this.signedGet(targetUrl).then((text: string): ZhihuFeedPage => parseHotListResponse(text));
  }

  public fetchFollowFeed(url: string | null): Promise<ZhihuFeedPage> {
    const targetUrl = url !== null && url.length > 0 ? url :
      'https://www.zhihu.com/api/v3/moments?limit=10&desktop=true';
    return this.signedGet(targetUrl).then((text: string): ZhihuFeedPage => parseFeedResponse(text));
  }

  public fetchQuestionAnswers(questionId: string, url: string | null, order: string): Promise<ZhihuFeedPage> {
    const endpoint = 'https://www.zhihu.com/api/v4/questions/' + encodeURIComponent(questionId) + '/feeds';
    const targetUrl = url !== null && url.length > 0 ? url.replace(/^http:\/\//, 'https://') :
      endpoint + '?limit=20&order=' + order +
      '&include=data%5B*%5D.content%2Cexcerpt%2Cheadline%2Ctarget.author.badge_v2';
    if (!targetUrl.startsWith(endpoint + '?')) {
      return Promise.reject(new Error('回答分页地址无效'));
    }
    return this.signedGet(targetUrl).then((text: string): ZhihuFeedPage => parseFeedResponse(text));
  }

  public fetchAnswer(answerId: string): Promise<ZhihuContent> {
    const url = 'https://www.zhihu.com/api/v4/answers/' + answerId +
      '?include=content,voteup_count,comment_count,created_time,updated_time,excerpt,' +
      'question,author,author.is_followed,reaction,relationship.voting,favlists_count,ip_info,' +
      'is_collapsed,is_normal,thumbnail_info';
    return this.signedGet(url).then((text: string): ZhihuContent => {
      const content = new ZhihuContent();
      content.kind = ZhihuContentType.Answer;
      const raw = JSON.parse(text) as IRawTarget;
      content.id = String(raw.id ?? answerId);
      content.title = raw.question?.title ?? '';
      const rawContent = raw.content;
      if (typeof rawContent === 'string') {
        content.contentHtml = rawContent;
      } else {
        content.contentHtml = '';
      }
      content.authorName = raw.author?.name ?? '';
      content.authorAvatar = raw.author?.avatar_url ?? raw.author?.avatarUrl ?? '';
      content.authorToken = raw.author?.url_token ?? raw.author?.urlToken ?? '';
      content.authorHeadline = raw.author?.headline ?? '';
      const relation = raw.reaction?.relation;
      content.authorFollowed =
        raw.author?.is_following ?? raw.author?.isFollowing ?? raw.author?.is_followed ?? relation?.following ?? false;
      content.voteupCount = raw.voteup_count ?? raw.voteupCount ?? 0;
      content.commentCount = raw.comment_count ?? raw.commentCount ?? 0;
      content.favoriteCount = raw.favlists_count ?? 0;
      content.favorited = relation?.faved ?? false;
      content.createdTime = raw.created_time ?? raw.createdTime ?? 0;
      content.updatedTime = raw.updated_time ?? raw.updatedTime ?? 0;
      const vote = relation?.vote?.toLowerCase();
      content.voting = vote === 'up' ? 1 : (vote === 'down' ? -1 :
        (vote === 'neutral' ? 0 : (raw.voting ?? raw.relationship?.voting ?? 0)));
      content.publishLocation = typeof raw.ip_info === 'string' ? raw.ip_info : '';
      const questionUrl = raw.question?.url ?? '';
      const linkedQuestionId = /\/questions?\/(\d+)(?:[/?#]|$)/.exec(questionUrl)?.[1];
      content.questionId = linkedQuestionId ?? (raw.question?.id !== undefined ? String(raw.question.id) : '');
      content.shareUrl = 'https://www.zhihu.com/question/' + content.questionId + '/answer/' + content.id;
      return content;
    });
  }

  public fetchArticle(articleId: string): Promise<ZhihuContent> {
    const url = 'https://www.zhihu.com/api/v4/articles/' + articleId +
      '?include=content,voteup_count,comment_count,title,author,created,updated,excerpt,is_normal';
    return this.signedGet(url).then((text: string): ZhihuContent => {
      const content = new ZhihuContent();
      content.kind = ZhihuContentType.Article;
      const raw = JSON.parse(text) as IRawTarget;
      content.id = String(raw.id ?? articleId);
      content.title = raw.title ?? '';
      const rawContent = raw.content;
      if (typeof rawContent === 'string') {
        content.contentHtml = rawContent;
      } else {
        content.contentHtml = '';
      }
      content.authorName = raw.author?.name ?? '';
      content.authorAvatar = raw.author?.avatar_url ?? raw.author?.avatarUrl ?? '';
      content.authorToken = raw.author?.url_token ?? raw.author?.urlToken ?? '';
      content.authorHeadline = raw.author?.headline ?? '';
      content.voteupCount = raw.voteup_count ?? raw.voteupCount ?? 0;
      content.commentCount = raw.comment_count ?? raw.commentCount ?? 0;
      content.createdTime = raw.created ?? 0;
      content.updatedTime = raw.updated ?? 0;
      content.shareUrl = 'https://zhuanlan.zhihu.com/p/' + content.id;
      return content;
    });
  }

  public fetchPin(pinId: string): Promise<ZhihuContent> {
    const url = 'https://www.zhihu.com/api/v4/pins/' + pinId + '?include=topics';
    return this.signedGet(url).then((text: string): ZhihuContent => {
      const content = new ZhihuContent();
      content.kind = ZhihuContentType.Pin;
      const raw = JSON.parse(text) as IRawTarget;
      content.id = String(raw.id ?? pinId);
      content.title = raw.excerpt_title ?? raw.excerptTitle ?? '想法';
      const rawContent = raw.content;
      if (rawContent !== undefined && rawContent !== null) {
        content.contentHtml = buildPinHtml(rawContent);
      }
      content.authorName = raw.author?.name ?? '';
      content.authorAvatar = raw.author?.avatar_url ?? raw.author?.avatarUrl ?? '';
      content.authorToken = raw.author?.url_token ?? raw.author?.urlToken ?? '';
      content.voteupCount = raw.like_count ?? raw.likeCount ?? 0;
      content.commentCount = raw.comment_count ?? raw.commentCount ?? 0;
      content.shareUrl = 'https://www.zhihu.com/pin/' + content.id;
      return content;
    });
  }

  public fetchQuestion(questionId: string): Promise<ZhihuQuestion> {
    const url = 'https://www.zhihu.com/api/v4/questions/' + questionId +
      '?include=detail,voteup_count,answer_count,follower_count,visit_count,excerpt,created_time,updated_time';
    return this.signedGet(url).then((text: string): ZhihuQuestion => {
      const question = new ZhihuQuestion();
      const raw = JSON.parse(text) as IRawTarget;
      question.id = String(raw.id ?? questionId);
      question.title = raw.title ?? raw.name ?? '';
      const rawDetail = raw.detail;
      if (typeof rawDetail === 'string') {
        question.detailHtml = rawDetail;
      }
      question.answerCount = raw.answer_count ?? raw.answerCount ?? 0;
      question.followerCount = raw.follower_count ?? raw.followerCount ?? 0;
      question.visitCount = raw.visit_count ?? raw.visitCount ?? 0;
      question.excerpt = raw.excerpt ?? '';
      return question;
    });
  }

  public fetchPeopleAnswers(urlToken: string, url: string | null): Promise<ZhihuFeedPage> {
    const targetUrl = url !== null && url.length > 0 ? url :
      'https://www.zhihu.com/api/v4/members/' + urlToken + '/answers?sort_by=default&limit=20&offset=0';
    return this.signedGet(targetUrl).then((text: string): ZhihuFeedPage => parseContentListResponse(text));
  }

  public fetchPeopleArticles(urlToken: string, url: string | null): Promise<ZhihuFeedPage> {
    const targetUrl = url !== null && url.length > 0 ? url :
      'https://www.zhihu.com/api/v4/members/' + urlToken + '/articles?sort_by=default&limit=20&offset=0';
    return this.signedGet(targetUrl).then((text: string): ZhihuFeedPage => parseContentListResponse(text));
  }

  public fetchPeople(urlToken: string): Promise<ZhihuPerson> {
    const url = 'https://www.zhihu.com/api/v4/people/' + urlToken +
      '?include=locations,employments,gender,follower_count,answer_count,articles_count,pins_count,description';
    return this.signedGet(url).then((text: string): ZhihuPerson => {
      const raw = JSON.parse(text) as IRawPerson;
      const person = new ZhihuPerson();
      person.id = raw.id ?? '';
      person.name = raw.name ?? '';
      person.avatarUrl = raw.avatar_url ?? raw.avatarUrl ?? '';
      person.urlToken = raw.url_token ?? raw.urlToken ?? urlToken;
      person.headline = raw.headline ?? '';
      person.description = raw.description ?? '';
      person.followerCount = raw.follower_count ?? raw.followerCount ?? 0;
      person.answerCount = raw.answer_count ?? raw.answerCount ?? 0;
      person.articlesCount = raw.articles_count ?? raw.articlesCount ?? 0;
      return person;
    });
  }

  public fetchComments(kind: string, id: string, url: string | null, latest: boolean = false): Promise<ZhihuCommentPage> {
    const targetUrl = url !== null && url.length > 0 ? url :
      'https://www.zhihu.com/api/v4/comment_v5/' + kind + '/' + id +
      '/root_comment?order_by=' + (latest ? 'ts' : 'score') + '&limit=20&status=open';
    return this.signedGet(targetUrl).then((text: string): ZhihuCommentPage => parseCommentsResponse(text));
  }

  public fetchChildComments(commentId: string, url: string | null): Promise<ZhihuCommentPage> {
    const targetUrl = url !== null && url.length > 0 ? url :
      'https://www.zhihu.com/api/v4/comment_v5/comment/' + commentId +
      '/child_comment?limit=20&offset=0&order_by=score&status=open';
    return this.signedGet(targetUrl).then((text: string): ZhihuCommentPage => parseCommentsResponse(text));
  }

  public likeComment(commentId: string, liked: boolean): Promise<boolean> {
    const url = 'https://www.zhihu.com/api/v4/comments/' + commentId + '/like';
    const body: string = liked ? 'true' : 'false';
    return this.http.post(url, body, true).then((): boolean => true);
  }

  public search(query: string, url: string | null, filters?: ZhihuSearchFilters): Promise<ZhihuFeedPage> {
    let targetUrl = url ?? '';
    if (targetUrl.length === 0) {
      targetUrl = 'https://www.zhihu.com/api/v4/search_v3?gk_version=gz-gaokao&t=general&q=' +
        encodeURIComponent(query) + '&correction=1&offset=0&limit=20&tc=1&ad_info=1';
      if (filters !== undefined) {
        const active = filters.type.length > 0 || filters.sort.length > 0 || filters.time.length > 0;
        targetUrl += '&search_source=' + (active ? 'Filter' : 'Normal');
        if (filters.type.length > 0) {
          targetUrl += '&vertical=' + encodeURIComponent(filters.type) +
            '&vertical_info=0%2C0%2C0%2C0%2C0%2C0%2C0%2C0%2C0%2C0%2C0%2C0';
        }
        if (filters.sort.length > 0) {
          targetUrl += '&sort=' + encodeURIComponent(filters.sort);
        }
        if (filters.time.length > 0) {
          targetUrl += '&time_interval=' + encodeURIComponent(filters.time);
        }
      }
    }
    return this.signedGet(targetUrl).then((text: string): ZhihuFeedPage => parseSearchResponse(text));
  }

  public async fetchHotSearch(): Promise<string[]> {
    const response = await this.signedGet('https://www.zhihu.com/api/v4/search/hot_search');
    const raw = JSON.parse(response) as HotSearchResponse;
    const keywords: string[] = [];
    for (const entry of raw.hot_search_queries ?? []) {
      const query = entry.query?.trim() ?? '';
      if (query.length > 0 && keywords.indexOf(query) < 0) {
        keywords.push(query);
        if (keywords.length === 15) {
          break;
        }
      }
    }
    return keywords;
  }

  public searchSuggest(query: string): Promise<string[]> {
    const url = 'https://www.zhihu.com/api/v4/search/suggest?q=' + encodeURIComponent(query);
    return this.signedGet(url).then((text: string): string[] => {
      const suggestions: string[] = [];
      if (text.length === 0) {
        return suggestions;
      }
      const raw = JSON.parse(text) as Record<string, Object>;
      const data = raw['suggests'];
      if (Array.isArray(data)) {
        const list = data as Record<string, Object>[];
        for (let i = 0; i < list.length; i++) {
          const entryToken = list[i]['queryToken'];
          const displayQuery = list[i]['displayQuery'];
          const value = typeof displayQuery === 'string' ? displayQuery :
            (typeof entryToken === 'string' ? entryToken : '');
          if (value.length > 0) {
            suggestions.push(value);
          }
        }
      }
      return suggestions;
    });
  }

  public fetchMe(): Promise<IRawPerson> {
    const url = 'https://www.zhihu.com/api/v4/me';
    return this.signedGet(url).then((text: string): IRawPerson => JSON.parse(text) as IRawPerson);
  }

  public async fetchOnlineHistory(nextUrl: string): Promise<OnlineHistoryPage> {
    const url = nextUrl.length > 0 ? nextUrl.replace(/^http:\/\//, 'https://') :
      'https://api.zhihu.com/unify-consumption/read_history?offset=0&limit=10';
    if (!/^https:\/\/api\.zhihu\.com\/unify-consumption\/read_history(?:\?|$)/.test(url)) {
      throw new Error('在线历史分页地址无效');
    }
    return parseOnlineHistory(await this.signedGet(url));
  }

  private collectionUrl(path: string, nextUrl: string): string {
    const base = 'https://www.zhihu.com' + path;
    if (nextUrl.length === 0) {
      return base + '?offset=0&limit=20';
    }
    const url = nextUrl.replace(/^http:\/\//, 'https://');
    if (url !== base && !url.startsWith(base + '?')) {
      throw new Error('收藏夹分页地址无效');
    }
    return url;
  }

  public async fetchCollections(nextUrl: string): Promise<ZhihuCollectionPage> {
    if (!this.session.isLoggedIn()) {
      throw new Error('请先登录知乎');
    }
    if (this.session.user.urlToken.length === 0) {
      await this.refreshMe();
    }
    const token = this.session.user.urlToken;
    if (token.length === 0) {
      throw new Error('无法取得知乎账号信息');
    }
    const url = this.collectionUrl('/api/v4/people/' + encodeURIComponent(token) + '/collections', nextUrl);
    return parseCollections(await this.signedGet(url));
  }

  public async fetchCollectionItems(id: string, nextUrl: string): Promise<ZhihuFeedPage> {
    if (!this.session.isLoggedIn()) {
      throw new Error('请先登录知乎');
    }
    const url = this.collectionUrl('/api/v4/collections/' + encodeURIComponent(id) + '/items', nextUrl);
    return parseCollectionItems(await this.signedGet(url));
  }

  public async deleteOnlineHistory(entry: OnlineHistoryEntry): Promise<void> {
    if (!entry.contentToken || !entry.contentType) {
      throw new Error('缺少在线历史记录标识');
    }
    const pair: OnlineHistoryPair = {
      content_token: entry.contentToken,
      content_type: entry.contentType
    };
    const body: DeleteOnlineHistoryRequest = { pairs: [pair], clear: false };
    await this.http.ensureDevice();
    await this.http.post('https://api.zhihu.com/read_history/batch_del', JSON.stringify(body), true);
  }

  public voteContent(kind: string, id: string, voteType: string): Promise<void> {
    const url = 'https://www.zhihu.com/api/v4/' + kind + '/' + id + '/voteup';
    const bodyObj: Record<string, string> = { 'type': voteType };
    return this.http.post(url, JSON.stringify(bodyObj), true).then((): void => {
    });
  }

  public async voteAnswer(id: string, voteType: string): Promise<number | undefined> {
    const url = 'https://www.zhihu.com/api/v4/answers/' + encodeURIComponent(id) + '/voters';
    const body: Record<string, string> = { 'type': voteType };
    const response = await this.http.post(url, JSON.stringify(body), true);
    if (response.text.trim().length === 0) {
      return undefined;
    }
    const raw = JSON.parse(response.text) as IRawTarget;
    return raw.voteup_count ?? raw.voteupCount;
  }

  public async fetchAnswerCollections(id: string, nextUrl: string): Promise<ZhihuCollectionPage> {
    const url = 'https://api.zhihu.com/collections/contents/answer/' + encodeURIComponent(id);
    const target = nextUrl ? nextUrl.replace(/^http:\/\//, 'https://') : url + '?limit=50';
    if (!target.startsWith(url + '?')) {
      throw new Error('收藏夹分页地址无效');
    }
    const response = await this.http.get(target, false);
    return parseCollections(response.text);
  }

  public async setAnswerFavorite(id: string, collectionId: string, add: boolean): Promise<void> {
    const url = 'https://api.zhihu.com/collections/contents/answer/' + encodeURIComponent(id);
    const key = add ? 'add_collections' : 'remove_collections';
    await this.http.putForm(url, key + '=' + encodeURIComponent(collectionId));
  }

  public followPeople(urlToken: string, follow: boolean): Promise<void> {
    const url = 'https://www.zhihu.com/api/v4/members/' + urlToken + '/follow';
    if (follow) {
      return this.http.post(url, null, true).then((): void => {
      });
    }
    return this.http.delete(url, true).then((): void => {
    });
  }

  public fetchDailyLatest(): Promise<ZhihuDailySection> {
    const url = 'https://news-at.zhihu.com/api/4/stories/latest';
    return this.http.get(url, false).then((response: ZhihuHttpResponse): ZhihuDailySection => parseDailyResponse(response.text));
  }

  public fetchDailyBefore(date: string): Promise<ZhihuDailySection> {
    const url = 'https://news-at.zhihu.com/api/4/stories/before/' + date;
    return this.http.get(url, false).then((response: ZhihuHttpResponse): ZhihuDailySection => parseDailyResponse(response.text));
  }

  public fetchDailyStory(storyId: string): Promise<ZhihuDailyDetail> {
    const url = 'https://news-at.zhihu.com/api/4/story/' + storyId;
    return this.http.get(url, false).then((response: ZhihuHttpResponse): ZhihuDailyDetail => parseDailyDetail(response.text));
  }

  public async verifyLoginCookie(cookieString: string): Promise<ZhihuSession> {
    const candidate = new ZhihuSession();
    candidate.applyCookieString(cookieString);
    if (!candidate.isLoggedIn()) {
      throw new Error('未取得知乎登录凭证');
    }
    if (!candidate.getDc0()) {
      const device = await this.http.requestForLogin(http.RequestMethod.POST, '/udid', candidate, '{}');
      if (device.status !== 200 || !candidate.getDc0()) {
        throw new Error('无法初始化知乎会话，请重试');
      }
    }
    const response = await this.http.requestForLogin(http.RequestMethod.GET, '/api/v4/me', candidate, null, true);
    if (response.status === 403) {
      throw new Error('知乎暂时限制了账号校验，请稍后重试');
    }
    if (response.status !== 200) {
      throw new Error(response.status === 401 ? '登录已过期，请重新登录' : '知乎账号校验失败，请重试');
    }
    let me: IRawPerson;
    try {
      me = JSON.parse(response.text) as IRawPerson;
    } catch (error) {
      throw new Error('知乎账号响应格式异常，请重试');
    }
    if (!me || (typeof me.id !== 'string' && typeof me.id !== 'number') ||
      String(me.id).trim().length === 0 || !candidate.isLoggedIn()) {
      throw new Error('知乎未返回有效账号，请重新登录');
    }
    this.updateUser(candidate, me);
    return candidate;
  }

  public async loginWithCookieString(cookieString: string): Promise<void> {
    const candidate = await this.verifyLoginCookie(cookieString);
    await this.session.adoptVerifiedSession(candidate);
  }

  private updateUser(session: ZhihuSession, me: IRawPerson): void {
    session.user.id = String(me.id ?? '');
    session.user.name = me.name ?? '';
    session.user.avatarUrl = me.avatar_url ?? me.avatarUrl ?? '';
    session.user.urlToken = me.url_token ?? me.urlToken ?? '';
    session.user.headline = me.headline ?? '';
  }

  public async refreshMe(): Promise<void> {
    const revision = this.session.getRevision();
    const me = await this.fetchMe();
    if (this.session.getRevision() === revision) {
      this.updateUser(this.session, me);
      await this.session.persist();
    }
  }
}
