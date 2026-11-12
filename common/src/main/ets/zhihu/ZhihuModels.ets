/**
 * Zhihu data models + JSON normalizers.
 * Ported from DataHolder.kt / Feed.kt / DailyStory.kt (Kotlin, snake->camel transform),
 * here we read the raw wire format (snake_case, with camelCase fallbacks).
 */
import { ZhihuContentType } from './ZhihuContentType';

export interface IRawPaging {
  next?: string;
  next_url?: string;
  isEnd?: boolean;
  is_end?: boolean;
}

export interface IRawBadgeV2Display {
  title?: string;
}

export interface IRawBadgeV2 {
  mergedDisplay?: IRawBadgeV2Display;
  merged_display?: IRawBadgeV2Display;
}

export interface IRawPerson {
  id?: string;
  name?: string;
  urlToken?: string;
  url_token?: string;
  avatarUrl?: string;
  avatar_url?: string;
  avatarUrlTemplate?: string;
  avatar_url_template?: string;
  headline?: string;
  description?: string;
  gender?: number;
  type?: string;
  badgeV2?: IRawBadgeV2;
  badge_v2?: IRawBadgeV2;
  followerCount?: number;
  follower_count?: number;
  answerCount?: number;
  answer_count?: number;
  articlesCount?: number;
  articles_count?: number;
  pinsCount?: number;
  pins_count?: number;
  voteupCount?: number;
  voteup_count?: number;
  isFollowing?: boolean;
  is_following?: boolean;
}

export interface IRawQuestionRef {
  id?: string;
  title?: string;
  name?: string;
  excerpt?: string;
  answerCount?: number;
  answer_count?: number;
  followerCount?: number;
  follower_count?: number;
  visitCount?: number;
  visit_count?: number;
}

export interface IRawThumbnail {
  url?: string;
}

export interface IRawThumbnailInfo {
  count?: number;
  type?: string;
  thumbnails?: Object[];
}

export interface IRawPinContentItem {
  type?: string;
  content?: Object;
}

export interface IRawTopic {
  id?: string;
  name?: string;
  url?: string;
}

export interface IRawTarget {
  type?: string;
  id?: string;
  title?: string;
  name?: string;
  excerpt?: string;
  content?: Object;
  detail?: string;
  description?: string;
  voteupCount?: number;
  voteup_count?: number;
  commentCount?: number;
  comment_count?: number;
  likeCount?: number;
  like_count?: number;
  answerCount?: number;
  answer_count?: number;
  followerCount?: number;
  follower_count?: number;
  visitCount?: number;
  visit_count?: number;
  thanksCount?: number;
  thanks_count?: number;
  createdTime?: number;
  created_time?: number;
  created?: number;
  updatedTime?: number;
  updated_time?: number;
  updated?: number;
  thumbnail?: string;
  thumbnailInfo?: IRawThumbnailInfo;
  thumbnail_info?: IRawThumbnailInfo;
  imageUrl?: string;
  image_url?: string;
  author?: IRawPerson;
  question?: IRawQuestionRef;
  url?: string;
  topics?: IRawTopic[];
  excerptTitle?: string;
  excerpt_title?: string;
  excerptTitleNew?: string;
  videoUrl?: string;
  video_url?: string;
  playback?: Object;
  isFollowing?: boolean;
  is_following?: boolean;
  voting?: number;
  excerptFull?: string;
  excerpt_full?: string;
}

export interface IRawFeedEntry {
  type?: string;
  verb?: string;
  target?: IRawTarget;
  actionText?: string;
  action_text?: string;
  detailText?: string;
  detail_text?: string;
  children?: IRawHotChild[];
  id?: string;
  ad?: Object;
  object?: IRawTarget;
}

export interface IRawHotChild {
  thumbnail?: string;
  type?: string;
}

export interface IRawFeedResponse {
  data?: IRawFeedEntry[];
  paging?: IRawPaging;
  message?: string;
  error?: Object;
}

export interface IRawContentListResponse {
  data?: IRawTarget[];
  paging?: IRawPaging;
}

export class ZhihuFeedItem {
  contentType: ZhihuContentType = ZhihuContentType.Unknown;
  id: string = '';
  questionId: string = '';
  questionTitle: string = '';
  title: string = '';
  summary: string = '';
  authorName: string = '';
  authorAvatar: string = '';
  authorToken: string = '';
  authorHeadline: string = '';
  badgeTitle: string = '';
  voteupCount: number = 0;
  commentCount: number = 0;
  answerCount: number = 0;
  followerCount: number = 0;
  details: string = '';
  thumbnailUrl: string = '';
  createdTime: number = 0;
  updatedTime: number = 0;
  contentHtml: string = '';
  actionText: string = '';
  isEndorsement: boolean = false;
}

export class ZhihuFeedPage {
  items: ZhihuFeedItem[] = [];
  nextUrl: string = '';
  isEnd: boolean = false;
}

export interface IRawCommentAuthor {
  id?: string;
  name?: string;
  urlToken?: string;
  url_token?: string;
  avatarUrl?: string;
  avatar_url?: string;
  headline?: string;
}

export interface IRawComment {
  id?: string;
  content?: string;
  createdTime?: number;
  created_time?: number;
  liked?: boolean;
  likeCount?: number;
  like_count?: number;
  childCommentCount?: number;
  child_comment_count?: number;
  author?: IRawCommentAuthor;
  replyToAuthor?: IRawCommentAuthor;
  reply_to_author?: IRawCommentAuthor;
  isAuthor?: boolean;
  is_author?: boolean;
  url?: string;
  top?: boolean;
}

export interface IRawCommentPageResponse {
  data?: IRawComment[];
  page?: IRawPaging;
  paging?: IRawPaging;
}

export class ZhihuComment {
  id: string = '';
  content: string = '';
  createdTime: number = 0;
  liked: boolean = false;
  likeCount: number = 0;
  childCommentCount: number = 0;
  authorName: string = '';
  authorAvatar: string = '';
  authorToken: string = '';
  replyToName: string = '';
  isAuthor: boolean = false;
  top: boolean = false;
}

export class ZhihuCommentPage {
  comments: ZhihuComment[] = [];
  nextUrl: string = '';
  isEnd: boolean = false;
}

export interface IRawDailyStory {
  id?: number;
  title?: string;
  image?: string;
  thumbnail?: string;
  images?: string[];
}

export interface IRawDailyResponse {
  date?: string;
  stories?: IRawDailyStory[];
}

export class ZhihuDailyStory {
  id: string = '';
  title: string = '';
  imageUrl: string = '';
}

export class ZhihuDailySection {
  date: string = '';
  stories: ZhihuDailyStory[] = [];
}

export interface IRawDailyDetail {
  title?: string;
  body?: string;
  image_source?: string;
  imageSource?: string;
  share_url?: string;
}

export class ZhihuDailyDetail {
  title: string = '';
  bodyHtml: string = '';
  imageSource: string = '';
}

export class ZhihuContent {
  kind: ZhihuContentType = ZhihuContentType.Answer;
  id: string = '';
  title: string = '';
  contentHtml: string = '';
  authorName: string = '';
  authorAvatar: string = '';
  authorToken: string = '';
  authorHeadline: string = '';
  voteupCount: number = 0;
  commentCount: number = 0;
  createdTime: number = 0;
  updatedTime: number = 0;
  voting: number = 0;
  questionId: string = '';
  shareUrl: string = '';
}

export class ZhihuQuestion {
  id: string = '';
  title: string = '';
  detailHtml: string = '';
  answerCount: number = 0;
  followerCount: number = 0;
  visitCount: number = 0;
  excerpt: string = '';
}

export class ZhihuPerson {
  id: string = '';
  name: string = '';
  avatarUrl: string = '';
  urlToken: string = '';
  headline: string = '';
  description: string = '';
  followerCount: number = 0;
  answerCount: number = 0;
  articlesCount: number = 0;
  isFollowing: boolean = false;
}

export function formatCount(value: number): string {
  if (!Number.isFinite(value) || value < 0) {
    return '0';
  }
  if (value >= 100000000) {
    return trimNumber(value / 100000000) + ' 亿';
  }
  if (value >= 10000) {
    return trimNumber(value / 10000) + ' 万';
  }
  return String(Math.floor(value));
}

function trimNumber(value: number): string {
  const rounded = Math.round(value * 10) / 10;
  if (Math.abs(rounded - Math.floor(rounded)) < 0.05) {
    return String(Math.floor(rounded));
  }
  return String(rounded);
}

export function formatRelativeTime(timestampSeconds: number): string {
  if (timestampSeconds <= 0) {
    return '';
  }
  const now = Math.floor(Date.now() / 1000);
  const diff = now - timestampSeconds;
  if (diff < 60) {
    return '刚刚';
  }
  if (diff < 3600) {
    return Math.floor(diff / 60) + ' 分钟前';
  }
  if (diff < 86400) {
    return Math.floor(diff / 3600) + ' 小时前';
  }
  if (diff < 86400 * 30) {
    return Math.floor(diff / 86400) + ' 天前';
  }
  const date = new Date(timestampSeconds * 1000);
  return date.getFullYear() + '-' + pad2(date.getMonth() + 1) + '-' + pad2(date.getDate());
}

function pad2(value: number): string {
  if (value < 10) {
    return '0' + value;
  }
  return String(value);
}

export function stripHtml(html: string): string {
  if (html.length === 0) {
    return '';
  }
  let text = html.replace(/<br\s*\/?>/gi, ' ');
  text = text.replace(/<[^>]+>/g, '');
  text = text.replace(/&nbsp;/g, ' ');
  text = text.replace(/&amp;/g, '&');
  text = text.replace(/&lt;/g, '<');
  text = text.replace(/&gt;/g, '>');
  text = text.replace(/&quot;/g, '"');
  text = text.replace(/&#39;/g, "'");
  text = text.replace(/&hellip;/g, '…');
  return text.trim();
}

function firstThumbnailUrl(info: IRawThumbnailInfo | undefined): string {
  if (info === undefined || info.thumbnails === undefined) {
    return '';
  }
  const list = info.thumbnails;
  for (let i = 0; i < list.length; i++) {
    const entry = list[i];
    if (typeof entry === 'string') {
      return entry;
    }
    const thumb = entry as IRawThumbnail;
    if (thumb.url !== undefined && thumb.url.length > 0) {
      return thumb.url;
    }
  }
  return '';
}

function personField(person: IRawPerson | undefined): ZhihuFeedItem {
  const item = new ZhihuFeedItem();
  if (person !== undefined) {
    item.authorName = person.name ?? '';
    item.authorAvatar = person.avatar_url ?? person.avatarUrl ?? '';
    item.authorToken = person.url_token ?? person.urlToken ?? '';
    item.authorHeadline = person.headline ?? '';
    const badge = person.badge_v2 ?? person.badgeV2;
    if (badge !== undefined) {
      const display = badge.merged_display ?? badge.mergedDisplay;
      item.badgeTitle = display?.title ?? '';
    }
  }
  return item;
}

export function buildPinHtml(content: Object): string {
  if (!Array.isArray(content)) {
    return '';
  }
  const items = content as IRawPinContentItem[];
  let html = '';
  for (let i = 0; i < items.length; i++) {
    const entry = items[i];
    const entryType = entry.type ?? '';
    const inner = entry.content;
    if (entryType === 'text' && typeof inner === 'string') {
      html += '<p>' + inner + '</p>';
    } else if (entryType === 'image') {
      const imageInfo = inner as IRawThumbnail;
      const url = imageInfo?.url ?? '';
      if (url.length > 0) {
        html += '<p><img src="' + url + '"/></p>';
      }
    } else if (entryType === 'link') {
      const linkInfo = inner as IRawTarget;
      const url = linkInfo?.url ?? '';
      const title = linkInfo?.title ?? url;
      if (url.length > 0) {
        html += '<p><a href="' + url + '">' + title + '</a></p>';
      }
    }
  }
  return html;
}

export function normalizeTarget(target: IRawTarget): ZhihuFeedItem | null {
  if (target === undefined || target === null) {
    return null;
  }
  const type = target.type ?? '';
  const author = personField(target.author);
  const item = author;
  const question = target.question;
  let questionTitle = '';
  if (question !== undefined) {
    questionTitle = question.title ?? question.name ?? '';
    item.questionId = question.id !== undefined ? String(question.id) : '';
  }
  if (type === 'answer') {
    item.contentType = ZhihuContentType.Answer;
    item.id = String(target.id ?? '');
    item.title = questionTitle;
    item.questionTitle = questionTitle;
    item.summary = stripHtml(target.excerpt ?? '');
    item.voteupCount = target.voteup_count ?? target.voteupCount ?? 0;
    item.commentCount = target.comment_count ?? target.commentCount ?? 0;
    item.createdTime = target.created_time ?? target.createdTime ?? 0;
    item.updatedTime = target.updated_time ?? target.updatedTime ?? 0;
    item.details = '回答 · ' + formatCount(item.voteupCount) + ' 赞同 · ' +
      formatCount(item.commentCount) + ' 评论';
    const thumbnail = target.thumbnail ?? '';
    if (thumbnail.length > 0) {
      item.thumbnailUrl = thumbnail;
    } else {
      const info = target.thumbnail_info ?? target.thumbnailInfo;
      item.thumbnailUrl = firstThumbnailUrl(info);
    }
    if (typeof target.content === 'string') {
      item.contentHtml = target.content;
    }
  } else if (type === 'article') {
    item.contentType = ZhihuContentType.Article;
    item.id = String(target.id ?? '');
    item.title = target.title ?? '';
    item.summary = stripHtml(target.excerpt ?? '');
    item.voteupCount = target.voteup_count ?? target.voteupCount ?? 0;
    item.commentCount = target.comment_count ?? target.commentCount ?? 0;
    item.createdTime = target.created ?? 0;
    item.updatedTime = target.updated ?? 0;
    item.details = '文章 · ' + formatCount(item.voteupCount) + ' 赞同 · ' +
      formatCount(item.commentCount) + ' 评论';
    item.thumbnailUrl = target.image_url ?? target.imageUrl ?? '';
    if (typeof target.content === 'string') {
      item.contentHtml = target.content;
    }
  } else if (type === 'pin') {
    item.contentType = ZhihuContentType.Pin;
    item.id = String(target.id ?? '');
    const pinHtml = target.content !== undefined ? buildPinHtml(target.content) : '';
    const excerpt = target.excerpt_title ?? target.excerptTitle ?? '';
    item.title = excerpt.length > 0 ? excerpt : (pinHtml.length > 0 ? stripHtml(pinHtml) : '想法');
    item.summary = stripHtml(pinHtml);
    item.voteupCount = target.like_count ?? target.likeCount ?? 0;
    item.commentCount = target.comment_count ?? target.commentCount ?? 0;
    item.details = '想法 · ' + formatCount(item.voteupCount) + ' 赞 · ' +
      formatCount(item.commentCount) + ' 评论';
  } else if (type === 'zvideo') {
    item.contentType = ZhihuContentType.Video;
    item.id = String(target.id ?? '');
    item.title = target.title ?? stripHtml(target.description ?? '');
    item.summary = stripHtml(target.description ?? '');
    item.voteupCount = target.voteup_count ?? target.voteupCount ?? 0;
    item.commentCount = target.comment_count ?? target.commentCount ?? 0;
    item.details = '视频 · ' + formatCount(item.voteupCount) + ' 赞 · ' +
      formatCount(item.commentCount) + ' 评论';
    item.thumbnailUrl = target.image_url ?? target.imageUrl ?? target.thumbnail ?? '';
  } else if (type === 'question') {
    item.contentType = ZhihuContentType.Question;
    item.id = String(target.id ?? '');
    item.title = target.title ?? target.name ?? questionTitle;
    item.questionId = String(target.id ?? '');
    item.summary = stripHtml(target.excerpt ?? '');
    item.answerCount = target.answer_count ?? target.answerCount ?? (question?.answer_count ?? 0);
    item.followerCount = target.follower_count ?? target.followerCount ?? (question?.follower_count ?? 0);
    item.details = '问题 · ' + formatCount(item.followerCount) + ' 关注 · ' +
      formatCount(item.answerCount) + ' 回答';
  } else {
    return null;
  }
  return item;
}

function pagingOf(raw: IRawFeedResponse): IRawPaging {
  const paging = raw.paging;
  if (paging !== undefined) {
    return paging;
  }
  const empty: IRawPaging = {};
  return empty;
}

export function parseFeedResponse(text: string): ZhihuFeedPage {
  const page = new ZhihuFeedPage();
  if (text.length === 0) {
    return page;
  }
  const raw = JSON.parse(text) as IRawFeedResponse;
  const entries = raw.data;
  if (entries !== undefined) {
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      const entryType = entry.type ?? '';
      if (entryType.indexOf('advert') >= 0) {
        continue;
      }
      let target = entry.target;
      if (target === undefined && entry.object !== undefined) {
        target = entry.object;
      }
      if (target === undefined) {
        continue;
      }
      const item = normalizeTarget(target);
      if (item === null) {
        continue;
      }
      const actionText = entry.action_text ?? entry.actionText ?? '';
      if (actionText.length > 0) {
        item.actionText = actionText;
      }
      page.items.push(item);
    }
  }
  const paging = pagingOf(raw);
  page.nextUrl = paging.next ?? paging.next_url ?? '';
  page.isEnd = paging.is_end ?? paging.isEnd ?? false;
  return page;
}

export function parseHotListResponse(text: string): ZhihuFeedPage {
  const page = new ZhihuFeedPage();
  if (text.length === 0) {
    return page;
  }
  const raw = JSON.parse(text) as IRawFeedResponse;
  const entries = raw.data;
  if (entries !== undefined) {
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      const target = entry.target;
      if (target === undefined) {
        continue;
      }
      const item = normalizeTarget(target);
      if (item === null) {
        continue;
      }
      const detailText = entry.detail_text ?? entry.detailText ?? '';
      if (detailText.length > 0) {
        item.details = detailText;
      }
      const children = entry.children;
      if (children !== undefined && children.length > 0) {
        item.thumbnailUrl = children[0].thumbnail ?? item.thumbnailUrl;
      }
      page.items.push(item);
    }
  }
  const paging = pagingOf(raw);
  page.nextUrl = paging.next ?? paging.next_url ?? '';
  page.isEnd = paging.is_end ?? paging.isEnd ?? true;
  return page;
}

/**
 * Parses member answers/articles style responses where data[] holds content objects directly.
 */
export function parseContentListResponse(text: string): ZhihuFeedPage {
  const page = new ZhihuFeedPage();
  if (text.length === 0) {
    return page;
  }
  const raw = JSON.parse(text) as IRawContentListResponse;
  const entries = raw.data;
  if (entries !== undefined) {
    for (let i = 0; i < entries.length; i++) {
      const item = normalizeTarget(entries[i]);
      if (item !== null) {
        page.items.push(item);
      }
    }
  }
  const paging = raw.paging;
  page.nextUrl = paging?.next ?? paging?.next_url ?? '';
  page.isEnd = paging?.is_end ?? paging?.isEnd ?? false;
  return page;
}

export interface IRawComponentImage {
  url?: string;
}

export interface IRawComponentElement {
  id?: string;
  type?: string;
  style?: string;
  text?: string;
  count?: number;
  reaction?: string;
  image?: IRawComponentImage;
  elements?: Object[];
}

export interface IRawComponentAction {
  parameter?: string;
}

export interface IRawComponentCard {
  type?: string;
  id?: string;
  action?: IRawComponentAction;
  children?: Object[];
}

export interface IRawMobileFeedResponse {
  data?: Object[];
  dataV1?: Object[];
  paging?: IRawPaging;
}

function componentFindById(list: Object[], value: string): IRawComponentElement | null {
  for (let i = 0; i < list.length; i++) {
    const entry = list[i] as IRawComponentElement;
    if (entry.id === value) {
      return entry;
    }
  }
  return null;
}

function componentFindByType(list: Object[], value: string): IRawComponentElement | null {
  for (let i = 0; i < list.length; i++) {
    const entry = list[i] as IRawComponentElement;
    if (entry.type === value) {
      return entry;
    }
  }
  return null;
}

function componentFindByStyle(list: Object[], value: string): IRawComponentElement | null {
  for (let i = 0; i < list.length; i++) {
    const entry = list[i] as IRawComponentElement;
    if (entry.style === value) {
      return entry;
    }
  }
  return null;
}

function componentFindByReaction(list: Object[], value: string): IRawComponentElement | null {
  for (let i = 0; i < list.length; i++) {
    const entry = list[i] as IRawComponentElement;
    if (entry.reaction === value) {
      return entry;
    }
  }
  return null;
}

class ResolvedRoute {
  contentType: ZhihuContentType = ZhihuContentType.Unknown;
  id: string = '';
  questionId: string = '';
}

function routeOf(contentType: ZhihuContentType, id: string, questionId: string): ResolvedRoute {
  const route = new ResolvedRoute();
  route.contentType = contentType;
  route.id = id;
  route.questionId = questionId;
  return route;
}

function decodeUrlPart(input: string): string {
  try {
    return decodeURIComponent(input);
  } catch (error) {
    return input;
  }
}

function isAllDigits(value: string): boolean {
  if (value.length === 0) {
    return false;
  }
  for (let i = 0; i < value.length; i++) {
    const code = value.charCodeAt(i);
    if (code < 48 || code > 57) {
      return false;
    }
  }
  return true;
}

function queryValue(query: string, key: string): string | null {
  const parts = query.split('&');
  for (let i = 0; i < parts.length; i++) {
    const eq = parts[i].indexOf('=');
    if (eq > 0 && parts[i].substring(0, eq) === key) {
      return decodeUrlPart(parts[i].substring(eq + 1));
    }
  }
  return null;
}

/**
 * Port of resolveContent() from NavDestination.kt, limited to content routes
 * used by the mobile recommend feed (answers/questions/articles/pins).
 */
function resolveContentRoute(url: string, depth: number): ResolvedRoute | null {
  if (depth > 3) {
    return null;
  }
  const schemeEnd = url.indexOf('://');
  if (schemeEnd < 0) {
    return null;
  }
  const scheme = url.substring(0, schemeEnd).toLowerCase();
  const rest = url.substring(schemeEnd + 3);
  if (scheme === 'http' || scheme === 'https') {
    const pathStart = rest.indexOf('/');
    const host = (pathStart < 0 ? rest : rest.substring(0, pathStart)).toLowerCase();
    const pathAndQuery = pathStart < 0 ? '' : rest.substring(pathStart + 1);
    const queryStart = pathAndQuery.indexOf('?');
    const pathPart = queryStart < 0 ? pathAndQuery : pathAndQuery.substring(0, queryStart);
    const queryPart = queryStart < 0 ? '' : pathAndQuery.substring(queryStart + 1);
    const segments: string[] = pathPart.length > 0 ? pathPart.split('/') : [];
    if (host === 'www.zhihu.com' || host === 'zhihu.com') {
      if (segments.length === 4 && segments[0] === 'question' && segments[2] === 'answer' &&
        isAllDigits(segments[1]) && isAllDigits(segments[3])) {
        return routeOf(ZhihuContentType.Answer, segments[3], segments[1]);
      }
      if (segments.length === 2 && segments[0] === 'answer' && isAllDigits(segments[1])) {
        return routeOf(ZhihuContentType.Answer, segments[1], '');
      }
      if (segments.length === 2 && segments[0] === 'question' && isAllDigits(segments[1])) {
        return routeOf(ZhihuContentType.Question, segments[1], segments[1]);
      }
      if (segments.length === 2 && segments[0] === 'pin' && isAllDigits(segments[1])) {
        return routeOf(ZhihuContentType.Pin, segments[1], '');
      }
      if (segments.length === 3 && segments[0] === 'appview' && isAllDigits(segments[2])) {
        if (segments[1] === 'pin') {
          return routeOf(ZhihuContentType.Pin, segments[2], '');
        }
        if (segments[1] === 'answer') {
          return routeOf(ZhihuContentType.Answer, segments[2], '');
        }
        if (segments[1] === 'p') {
          return routeOf(ZhihuContentType.Article, segments[2], '');
        }
      }
      return null;
    }
    if (host === 'zhuanlan.zhihu.com') {
      if (segments.length === 2 && segments[0] === 'p' && isAllDigits(segments[1])) {
        return routeOf(ZhihuContentType.Article, segments[1], '');
      }
      return null;
    }
    if (host === 'link.zhihu.com') {
      const target = queryValue(queryPart, 'target');
      if (target !== null) {
        return resolveContentRoute(target, depth + 1);
      }
      return null;
    }
    return null;
  }
  if (scheme === 'zhihu') {
    const slash = rest.indexOf('/');
    if (slash < 0) {
      return null;
    }
    const host = rest.substring(0, slash).toLowerCase();
    const pathPart = rest.substring(slash + 1);
    const queryStart = pathPart.indexOf('?');
    const segSource = queryStart < 0 ? pathPart : pathPart.substring(0, queryStart);
    const segments: string[] = segSource.length > 0 ? segSource.split('/') : [];
    if (segments.length < 1) {
      return null;
    }
    if (host === 'answers' && isAllDigits(segments[0])) {
      return routeOf(ZhihuContentType.Answer, segments[0], '');
    }
    if (host === 'questions' && isAllDigits(segments[0])) {
      return routeOf(ZhihuContentType.Question, segments[0], segments[0]);
    }
    if (host === 'articles' && isAllDigits(segments[0])) {
      return routeOf(ZhihuContentType.Article, segments[0], '');
    }
    if (host === 'pin' && isAllDigits(segments[0])) {
      return routeOf(ZhihuContentType.Pin, segments[0], '');
    }
  }
  return null;
}

/**
 * Port of parseMobileHomeFeedDisplayItem() from AndroidHomeFeedViewModel.kt:
 * parses a single ComponentCard from api.zhihu.com/topstory/recommend.
 */
function parseMobileHomeFeedCard(cardRaw: Object): ZhihuFeedItem | null {
  const card = cardRaw as IRawComponentCard;
  if (card.type !== 'ComponentCard') {
    return null;
  }
  const action = card.action;
  const parameter = action?.parameter ?? '';
  if (parameter.length === 0) {
    return null;
  }
  const markerIndex = parameter.indexOf('route_url=');
  const routePart = markerIndex >= 0 ? parameter.substring(markerIndex + 'route_url='.length) : parameter;
  const route = resolveContentRoute(decodeUrlPart(routePart), 0);
  if (route === null) {
    return null;
  }
  const children = card.children;
  if (children === undefined || children.length === 0) {
    return null;
  }
  const titleChild = componentFindById(children, 'Text');
  let title = '';
  if (route.contentType === ZhihuContentType.Pin) {
    title = titleChild?.text ?? '';
  } else {
    if (titleChild === null || titleChild.text === undefined) {
      return null;
    }
    title = titleChild.text;
  }
  const summaryChild = componentFindById(children, 'text_pin_summary');
  if (summaryChild === null || summaryChild.text === undefined) {
    return null;
  }
  const summary = summaryChild.text;
  const lineChildren: Object[] = [];
  for (let i = 0; i < children.length; i++) {
    const entry = children[i] as IRawComponentElement;
    if (entry.type === 'Line') {
      lineChildren.push(children[i]);
    }
  }
  if (lineChildren.length < 2) {
    return null;
  }
  const footer = lineChildren[1] as IRawComponentElement;
  const footerElements = footer.elements ?? [];
  const vote = componentFindByReaction(footerElements, 'Vote');
  const commentReaction = componentFindByReaction(footerElements, 'Comment');
  const collect = componentFindByReaction(footerElements, 'Collect');
  let footerText = '';
  if (vote !== null && commentReaction !== null && collect !== null) {
    footerText = String(vote.count ?? 0) + ' 赞同 · ' + String(commentReaction.count ?? 0) +
      ' 评论 · ' + String(collect.count ?? 0) + ' 收藏';
  } else {
    const footerTextElement = componentFindByType(footerElements, 'Text');
    if (footerTextElement === null || footerTextElement.text === undefined) {
      return null;
    }
    footerText = footerTextElement.text;
  }
  let authorElements: Object[] | null = null;
  for (let i = 0; i < children.length; i++) {
    const entry = children[i] as IRawComponentElement;
    const style = entry.style ?? '';
    if (style.indexOf('RecommendAuthorLine') === 0 || style.indexOf('LineAuthor_default') === 0) {
      authorElements = entry.elements ?? [];
      break;
    }
  }
  if (authorElements === null) {
    return null;
  }
  const avatarElement = componentFindByStyle(authorElements, 'Avatar_default');
  if (avatarElement === null) {
    return null;
  }
  const avatar = avatarElement.image?.url ?? '';
  const authorTextElement = componentFindByType(authorElements, 'Text');
  if (authorTextElement === null || authorTextElement.text === undefined) {
    return null;
  }
  const item = new ZhihuFeedItem();
  item.contentType = route.contentType;
  item.id = route.id;
  item.questionId = route.questionId;
  item.title = title;
  item.summary = summary;
  item.authorName = authorTextElement.text;
  item.authorAvatar = avatar;
  item.details = footerText + ' · 手机版推荐';
  return item;
}

/**
 * Parses the mobile home feed response from api.zhihu.com/topstory/recommend
 * (ComponentCard format, see AndroidHomeFeedViewModel.kt).
 */
export function parseMobileHomeFeedResponse(text: string): ZhihuFeedPage {
  const page = new ZhihuFeedPage();
  if (text.length === 0) {
    return page;
  }
  const raw = JSON.parse(text) as IRawMobileFeedResponse;
  let cards = raw.data;
  if (cards === undefined || cards.length === 0) {
    cards = raw.dataV1;
  }
  if (cards !== undefined) {
    for (let i = 0; i < cards.length; i++) {
      const item = parseMobileHomeFeedCard(cards[i]);
      if (item !== null) {
        page.items.push(item);
      }
    }
  }
  const paging = raw.paging;
  page.nextUrl = paging?.next ?? paging?.next_url ?? '';
  page.isEnd = paging?.is_end ?? paging?.isEnd ?? false;
  return page;
}

export function parseSearchResponse(text: string): ZhihuFeedPage {
  const page = new ZhihuFeedPage();
  if (text.length === 0) {
    return page;
  }
  const raw = JSON.parse(text) as IRawFeedResponse;
  const entries = raw.data;
  if (entries !== undefined) {
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      const entryType = entry.type ?? '';
      const object = entry.object ?? entry.target;
      if (object === undefined) {
        continue;
      }
      if (entryType === 'people_result') {
        const item = new ZhihuFeedItem();
        item.contentType = ZhihuContentType.People;
        const person = object as IRawPerson;
        item.id = person.id ?? '';
        item.title = person.name ?? '';
        item.authorName = person.name ?? '';
        item.authorAvatar = person.avatar_url ?? person.avatarUrl ?? '';
        item.authorToken = person.url_token ?? person.urlToken ?? '';
        item.summary = person.headline ?? '';
        item.details = '用户';
        page.items.push(item);
        continue;
      }
      const item = normalizeTarget(object);
      if (item !== null) {
        page.items.push(item);
      }
    }
  }
  const paging = pagingOf(raw);
  page.nextUrl = paging.next ?? paging.next_url ?? '';
  page.isEnd = paging.is_end ?? paging.isEnd ?? true;
  return page;
}

export function parseCommentsResponse(text: string): ZhihuCommentPage {
  const page = new ZhihuCommentPage();
  if (text.length === 0) {
    return page;
  }
  const raw = JSON.parse(text) as IRawCommentPageResponse;
  const entries = raw.data;
  if (entries !== undefined) {
    for (let i = 0; i < entries.length; i++) {
      const rawComment = entries[i];
      const comment = new ZhihuComment();
      comment.id = rawComment.id ?? '';
      comment.content = rawComment.content ?? '';
      comment.createdTime = rawComment.createdTime ?? rawComment.created_time ?? 0;
      comment.liked = rawComment.liked ?? false;
      comment.likeCount = rawComment.likeCount ?? rawComment.like_count ?? 0;
      comment.childCommentCount = rawComment.childCommentCount ?? rawComment.child_comment_count ?? 0;
      comment.isAuthor = rawComment.isAuthor ?? rawComment.is_author ?? false;
      comment.top = rawComment.top ?? false;
      const author = rawComment.author;
      if (author !== undefined) {
        comment.authorName = author.name ?? '';
        comment.authorAvatar = author.avatar_url ?? author.avatarUrl ?? '';
        comment.authorToken = author.url_token ?? author.urlToken ?? '';
      }
      const replyTo = rawComment.replyToAuthor ?? rawComment.reply_to_author;
      if (replyTo !== undefined) {
        comment.replyToName = replyTo.name ?? '';
      }
      if (comment.id.length > 0) {
        page.comments.push(comment);
      }
    }
  }
  const paging = raw.page ?? raw.paging;
  if (paging !== undefined) {
    page.nextUrl = paging.next ?? paging.next_url ?? '';
    page.isEnd = paging.is_end ?? paging.isEnd ?? true;
  } else {
    page.isEnd = true;
  }
  return page;
}

export function parseDailyResponse(text: string): ZhihuDailySection {
  const section = new ZhihuDailySection();
  if (text.length === 0) {
    return section;
  }
  const raw = JSON.parse(text) as IRawDailyResponse;
  section.date = raw.date ?? '';
  const stories = raw.stories;
  if (stories !== undefined) {
    for (let i = 0; i < stories.length; i++) {
      const rawStory = stories[i];
      const story = new ZhihuDailyStory();
      story.id = rawStory.id !== undefined ? String(rawStory.id) : '';
      story.title = rawStory.title ?? '';
      const images = rawStory.images;
      if (images !== undefined && images.length > 0) {
        story.imageUrl = images[0];
      } else {
        story.imageUrl = rawStory.image ?? rawStory.thumbnail ?? '';
      }
      if (story.id.length > 0) {
        section.stories.push(story);
      }
    }
  }
  return section;
}

export function parseDailyDetail(text: string): ZhihuDailyDetail {
  const detail = new ZhihuDailyDetail();
  if (text.length === 0) {
    return detail;
  }
  const raw = JSON.parse(text) as IRawDailyDetail;
  detail.title = raw.title ?? '';
  detail.bodyHtml = raw.body ?? '';
  detail.imageSource = raw.image_source ?? raw.imageSource ?? '';
  return detail;
}

export function parsePerson(target: IRawTarget, personRaw: IRawPerson | undefined): ZhihuPerson {
  const person = new ZhihuPerson();
  if (personRaw !== undefined) {
    person.id = personRaw.id ?? '';
    person.name = personRaw.name ?? '';
    person.avatarUrl = personRaw.avatar_url ?? personRaw.avatarUrl ?? '';
    person.urlToken = personRaw.url_token ?? personRaw.urlToken ?? '';
    person.headline = personRaw.headline ?? '';
    person.description = personRaw.description ?? '';
    person.followerCount = personRaw.follower_count ?? personRaw.followerCount ?? 0;
    person.answerCount = personRaw.answer_count ?? personRaw.answerCount ?? 0;
    person.articlesCount = personRaw.articles_count ?? personRaw.articlesCount ?? 0;
    person.isFollowing = personRaw.is_following ?? personRaw.isFollowing ?? false;
  }
  if (person.urlToken.length === 0 && target.url !== undefined) {
    person.urlToken = target.url;
  }
  return person;
}
