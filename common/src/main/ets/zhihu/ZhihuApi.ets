/**
 * Zhihu API endpoints, ported from ZhihuApiClients / viewmodels (Kotlin).
 */
import { ZhihuHttp, ZhihuHttpResponse } from './ZhihuHttp';
import { ZhihuSession } from './ZhihuSession';
import { ZhihuContentType } from './ZhihuContentType';
import {
  ZhihuFeedPage,
  ZhihuCommentPage,
  ZhihuContent,
  ZhihuQuestion,
  ZhihuPerson,
  ZhihuDailySection,
  ZhihuDailyDetail,
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
  buildPinHtml,
  stripHtml,
  formatCount
} from './ZhihuModels';

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
    const targetUrl = url !== null && url.length > 0 ? url :
      'https://www.zhihu.com/api/v4/questions/' + questionId + '/feeds?limit=10&offset=0&order=' + order +
      '&include=data%5B*%5D.is_normal%2Ccollapsed_count%2Creviewing_count%2Ccan_comment%2Ccomment_count%2Ccontent%2Cvoteup_count%2Cexcerpt%2Ccreated_time%2Cupdated_time%2Crelationship.voting%2Cis_collapsed%2Cthumbnail_info';
    return this.signedGet(targetUrl).then((text: string): ZhihuFeedPage => parseFeedResponse(text));
  }

  public fetchAnswer(answerId: string): Promise<ZhihuContent> {
    const url = 'https://www.zhihu.com/api/v4/answers/' + answerId +
      '?include=content,voteup_count,comment_count,created_time,updated_time,excerpt,' +
      'question,author,relationship.voting,is_collapsed,is_normal,thumbnail_info';
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
      content.voteupCount = raw.voteup_count ?? raw.voteupCount ?? 0;
      content.commentCount = raw.comment_count ?? raw.commentCount ?? 0;
      content.createdTime = raw.created_time ?? raw.createdTime ?? 0;
      content.updatedTime = raw.updated_time ?? raw.updatedTime ?? 0;
      content.voting = raw.voting ?? 0;
      content.questionId = raw.question?.id !== undefined ? String(raw.question.id) : '';
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

  public fetchComments(kind: string, id: string, url: string | null): Promise<ZhihuCommentPage> {
    const targetUrl = url !== null && url.length > 0 ? url :
      'https://www.zhihu.com/api/v4/comment_v5/' + kind + '/' + id +
      '/root_comment?order_by=score&limit=20&status=open';
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

  public search(query: string, url: string | null): Promise<ZhihuFeedPage> {
    const targetUrl = url !== null && url.length > 0 ? url :
      'https://www.zhihu.com/api/v4/search_v3?gk_version=gz-gaokao&t=general&q=' + encodeURIComponent(query) +
      '&correction=1&offset=0&limit=20&tc=1&ad_info=1';
    return this.signedGet(targetUrl).then((text: string): ZhihuFeedPage => parseSearchResponse(text));
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

  public voteContent(kind: string, id: string, voteType: string): Promise<void> {
    const url = 'https://www.zhihu.com/api/v4/' + kind + '/' + id + '/voteup';
    const bodyObj: Record<string, string> = { 'type': voteType };
    return this.http.post(url, JSON.stringify(bodyObj), true).then((): void => {
    });
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

  /**
   * Login with a raw cookie string (contains z_c0). Verifies via /api/v4/me.
   */
  public async loginWithCookieString(cookieString: string): Promise<void> {
    this.session.applyCookieString(cookieString);
    const me = await this.fetchMe();
    this.session.user.id = me.id ?? '';
    this.session.user.name = me.name ?? '';
    this.session.user.avatarUrl = me.avatar_url ?? me.avatarUrl ?? '';
    this.session.user.urlToken = me.url_token ?? me.urlToken ?? '';
    this.session.user.headline = me.headline ?? '';
    await this.session.persist();
  }

  public async refreshMe(): Promise<void> {
    const me = await this.fetchMe();
    this.session.user.id = me.id ?? '';
    this.session.user.name = me.name ?? '';
    this.session.user.avatarUrl = me.avatar_url ?? me.avatarUrl ?? '';
    this.session.user.urlToken = me.url_token ?? me.urlToken ?? '';
    this.session.user.headline = me.headline ?? '';
    await this.session.persist();
  }
}
