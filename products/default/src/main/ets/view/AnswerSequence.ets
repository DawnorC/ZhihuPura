import { ZhihuApi, ZhihuContentType, ZhihuFeedPage } from '@ohos/common';
import { ContentPageParam } from './NavHelper';

export class AnswerSequence {
  private readonly ids: string[] = [];
  private readonly seenIds: Set<string> = new Set<string>();
  private readonly seenPages: Set<string> = new Set<string>();
  private initialPage?: Promise<void>;
  private initialized: boolean;
  private nextPage: string;
  private ended: boolean;
  private readonly order: string;

  constructor(params: ContentPageParam) {
    this.initialized = params.answerIds !== undefined;
    this.nextPage = params.nextAnswerPage ?? '';
    this.ended = this.initialized && (params.answerListEnd ?? this.nextPage.length === 0);
    this.order = params.answerOrder ?? 'default';
    this.addIds(params.answerIds ?? []);
  }

  private addIds(ids: string[]): void {
    for (const id of ids) {
      if (/^\d+$/.test(id) && !this.seenIds.has(id)) {
        this.seenIds.add(id);
        this.ids.push(id);
      }
    }
  }

  private async fetchPage(questionId: string): Promise<void> {
    const cursor = this.nextPage;
    if (this.seenPages.has(cursor)) {
      throw new Error('回答分页暂不可用');
    }
    const page: ZhihuFeedPage = await ZhihuApi.getInstance().fetchQuestionAnswers(questionId, cursor, this.order);
    if (!page.isEnd && (!page.nextUrl || page.nextUrl === cursor || this.seenPages.has(page.nextUrl))) {
      throw new Error('回答分页未继续');
    }
    this.addIds(page.items.filter(item => item.contentType === ZhihuContentType.Answer).map(item => item.id));
    this.seenPages.add(cursor);
    this.nextPage = page.nextUrl;
    this.ended = page.isEnd;
  }

  private async initialize(questionId: string, openedId: string): Promise<void> {
    if (!this.initialized) {
      await this.fetchPage(questionId);
      this.initialized = true;
    }
    if (!this.seenIds.has(openedId)) {
      this.seenIds.add(openedId);
      this.ids.unshift(openedId);
    }
  }

  async neighbors(questionId: string, openedId: string, anchor: string, direction: number,
    count: number): Promise<string[]> {
    if (this.initialPage === undefined) {
      this.initialPage = this.initialize(questionId, openedId);
    }
    try {
      await this.initialPage;
    } catch (error) {
      this.initialPage = undefined;
      throw new Error('无法读取回答列表');
    }
    if (direction < 0) {
      const index = this.ids.indexOf(anchor);
      return this.ids.slice(Math.max(0, index - count), index).reverse();
    }

    // Bound each background request without treating a skipped or repeated page as the end.
    for (let pages = 0; pages < 3 && !this.ended; pages++) {
      if (this.ids.length - this.ids.indexOf(anchor) - 1 >= count) {
        break;
      }
      try {
        await this.fetchPage(questionId);
      } catch (error) {
        if (this.ids.indexOf(anchor) === this.ids.length - 1) {
          throw new Error('无法加载更多回答');
        }
        break;
      }
    }
    const index = this.ids.indexOf(anchor);
    if (!this.ended && index === this.ids.length - 1) {
      throw new Error('暂未取得下一条回答');
    }
    return this.ids.slice(index + 1, index + 1 + count);
  }

  remove(id: string): void {
    const index = this.ids.indexOf(id);
    if (index >= 0) {
      this.ids.splice(index, 1);
    }
  }

  atEdge(anchor: string, direction: number): boolean {
    if (!this.initialized) {
      return false;
    }
    return direction < 0 ? this.ids[0] === anchor :
      this.ended && this.ids[this.ids.length - 1] === anchor;
  }
}
