import {
  HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationMenuItemOptions, HdsNavigationTitleBarOptions,
  IconStyleMode, TextStyleMode
} from '@kit.UIDesignKit';
/**
 * Content page (answer / article / pin reader), ported from ArticleScreen / AnswerPage (Kotlin).
 * Content HTML rendered in an embedded Web component, with vote / comment / share action bar.
 */
import { webview } from '@kit.ArkWeb';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { createGlassMaterial, spatialTitleBar, MINI_TITLE_BAR_HEIGHT } from '../view/NavigationChrome';
import {
  ANSWER_ACTION_COUNT_OFFSET, ANSWER_ACTION_ICON_SIZE, ANSWER_ACTION_ORIGIN, ANSWER_DOCUMENT_SCRIPT, ANSWER_DOCUMENT_STYLE, ANSWER_SCROLLBAR_HTML,
  ANSWER_VOTE_PATH,
  answerActionCount, answerVoteText, buildAnswerSection
} from '../view/AnswerDocument';
import { AnswerSequence } from '../view/AnswerSequence';
import { loadReaderDocument, updateReaderTopInset } from '../view/ReaderDocument';
import {
  HistoryStore,
  ZhihuApi,
  ZhihuCollection,
  ZhihuContent,
  ZhihuHttpError,
  ZhihuSession,
  formatRelativeTime
} from '@ohos/common';
import { LoadingView, ErrorView } from '../view/Widgets';
import {
  ContentPageParam,
  CommentsPageParam,
  PeoplePageParam,
  QuestionPageParam,
  showToast,
  copyToClipboard,
  openInBrowser,
  APP_COLOR_BLUE,
  APP_COLOR_SECONDARY,
  APP_COLOR_TEXT
} from '../view/NavHelper';

const PREVIOUS_BUFFER: number = 2;
const NEXT_BUFFER: number = 3;
const PREFETCH_RETRY_DELAY: number = 2500;
const TITLE_DIRECTION_DISTANCE: number = 24;
const ANSWER_DOCK_HEIGHT: number = 52;
const ANSWER_DOCK_BOTTOM_GAP: number = 8;
const ANSWER_DOCK_ACTION_WIDTH: number = 42;
const ANSWER_ARROW_SIZE: number = 44;

interface AnswerPosition {
  id: string;
  offset: number;
  dockId: string | null;
  long: boolean;
  before: number | null;
  after: number | null;
}

@Component
export struct ContentPage {
  pathStack: NavPathStack = new NavPathStack();
  @State content: ZhihuContent | null = null;
  @StorageProp('statusBarHeightPx') @Watch('updateTopInset') private statusBarHeightPx: number = 0;
  @StorageProp('bottomSafeAreaPx') @Watch('updateDockInset') private bottomSafeAreaPx: number = 0;
  @State private webScrollOffset: number = 0;
  @State private compactAnswerTitle: boolean = false;
  @State private longAnswer: boolean = false;
  @State isLoading: boolean = true;
  @State hasError: boolean = false;
  @State errorMessage: string = '';
  @State voting: number = 0;
  @State voteCount: number = 0;
  @State private authorFollowed: boolean = false;
  @State private favorited: boolean = false;
  @State private favoriteCount: number = 0;
  @State pageTitle: string = '';
  @State private kind: string = 'answer';
  @State private questionId: string = '';
  private contentId: string = '';
  private webController: webview.WebviewController = new webview.WebviewController();
  private documentHtml: string = '';
  private webReady: boolean = false;
  private routeParams?: ContentPageParam;
  private sequence?: AnswerSequence;
  private openedAnswerId: string = '';
  private previousTask?: Promise<void>;
  private nextTask?: Promise<void>;
  private previousRetryAt: number = 0;
  private nextRetryAt: number = 0;
  private endMessage: string = '';
  private endRetry: boolean = false;
  @State private atFirstAnswer: boolean = false;
  @State private atLastAnswer: boolean = false;
  @State private jumpingAnswer: boolean = false;
  private readonly readerMaterial = createGlassMaterial();
  private readonly loadedAnswers: Map<string, ZhihuContent> = new Map();
  private renderedIds: string[] = [];
  private readerGeneration: number = 0;
  private checkingPosition: boolean = false;
  private recheckPosition: boolean = false;
  private answerCheckTimer: number = -1;
  private boundaryCheckPending: boolean = false;
  private beforeAnswerOffset: number = Number.NEGATIVE_INFINITY;
  private afterAnswerOffset: number = Number.POSITIVE_INFINITY;
  private lastReaderOffset: number = 0;
  private initialReaderOffset: number = 0;
  private readerMoved: boolean = false;
  private titleDirectionAnchor: number = 0;
  private adjustingScrollUntil: number = 0;
  private documentReady: boolean = false;
  private positioningInitialAnswer: boolean = false;
  private readonly voteRequests: Set<string> = new Set<string>();
  private readonly followRequests: Set<string> = new Set<string>();
  private readonly followedAuthors: Map<string, boolean> = new Map<string, boolean>();
  @State private collectionSheetOpen: boolean = false;
  @State private collectionChoices: ZhihuCollection[] = [];
  @State private collectionBusy: boolean = false;
  @State private collectionError: boolean = false;
  @State private nextCollectionPage: string = '';
  private collectionAnswer?: ZhihuContent;
  private collectionRequest: number = 0;
  private readonly collectionUpdates: Set<string> = new Set<string>();

  private getTitleInset(): number {
    return MINI_TITLE_BAR_HEIGHT + this.getUIContext().px2vp(this.statusBarHeightPx);
  }

  private updateTopInset(): void {
    if (this.webReady) {
      updateReaderTopInset(this.webController, this.getTitleInset());
    }
    this.scheduleAnswerCheck(true);
  }

  private updateDockInset(): void {
    this.scheduleAnswerCheck(true);
  }

  private buildDocument(content: ZhihuContent): string {
    const css: string = ':root{--reader-top-inset:' + this.getTitleInset() + 'px;}' +
      'body{margin:0;padding:16px;font-size:16px;line-height:1.75;color:#1A1A1A;' +
      'padding-top:calc(var(--reader-top-inset) + 16px);' +
      'word-break:break-word;background:#FFFFFF;font-family:"HarmonyOS Sans SC","PingFang SC","Microsoft YaHei",sans-serif;}' +
      'img{max-width:100%;height:auto;border-radius:4px;}' +
      'a{color:#0066FF;text-decoration:none;}' +
      'p{margin:0 0 12px 0;}' +
      'blockquote{margin:12px 0;padding:8px 12px;border-left:3px solid #E8E8E8;background:#F8F8F8;color:#555555;}' +
      'h1,h2,h3{margin:16px 0 8px 0;font-weight:bold;}' +
      'figure{margin:0 0 12px 0;}' +
      'code,pre{background:#F6F6F6;border-radius:4px;}' +
      'pre{padding:8px;overflow-x:auto;}' +
      'body{padding-bottom:' + (this.kind === 'answer' ? 80 : 140) + 'px;' +
      (this.kind === 'answer' ? '' : 'overflow-anchor:none;') + '}' +
      'hr{border:none;border-top:1px solid #F0F0F0;margin:16px 0;}';
    const script: string = 'function prepareReaderImages(container,lazy){for(const image of container.querySelectorAll("img")){' +
      'const source=image.getAttribute("data-actualsrc")||image.getAttribute("data-original");' +
      'if(lazy)image.loading="lazy";image.decoding="async";image.removeAttribute("srcset");' +
      'const width=Number(image.getAttribute("data-rawwidth"));const height=Number(image.getAttribute("data-rawheight"));' +
      'if(width>0&&height>0&&!image.hasAttribute("width")&&!image.hasAttribute("height")){' +
      'image.width=width;image.height=height;}if(source)image.src=source;}}';
    const answer = this.kind === 'answer';
    const last = this.renderedIds[this.renderedIds.length - 1];
    const retryLink = this.endRetry && last ?
      ' · <a href="' + ANSWER_ACTION_ORIGIN + encodeURIComponent(last) + '/retry">重试</a>' : '';
    const readerBody = answer ? '<template id="reader-initial-answers">' + this.buildAnswerBatch(this.renderedIds) +
      '</template><footer id="reader-answer-end" role="status">' +
      (this.endMessage || '正在预加载更多回答…') + retryLink + '</footer>' + ANSWER_SCROLLBAR_HTML : content.contentHtml;
    const readerScript = answer ? ANSWER_DOCUMENT_SCRIPT + 'mountInitialAnswers(' + JSON.stringify(this.openedAnswerId) +
      ');' : 'prepareReaderImages(document,false);';
    return '<!DOCTYPE html><html><head><meta charset="utf-8">' +
      '<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=3">' +
      '<style>' + css + (answer ? ANSWER_DOCUMENT_STYLE : '') + '</style></head><body>' + readerBody +
      '<script>' + script + readerScript + '</script></body></html>';
  }

  private buildAnswerBatch(ids: string[]): string {
    return ids.map((id: string): string => {
      const content = this.loadedAnswers.get(id);
      return content === undefined ? '' : buildAnswerSection(id, content);
    }).join('');
  }

  private load(): void {
    this.cancelAnswerCheck();
    this.isLoading = true;
    this.webScrollOffset = 0;
    this.lastReaderOffset = 0;
    this.initialReaderOffset = 0;
    this.readerMoved = false;
    this.titleDirectionAnchor = 0;
    this.adjustingScrollUntil = 0;
    this.beforeAnswerOffset = Number.NEGATIVE_INFINITY;
    this.afterAnswerOffset = Number.POSITIVE_INFINITY;
    this.compactAnswerTitle = false;
    this.longAnswer = false;
    this.content = null;
    this.hasError = false;
    this.documentHtml = '';
    this.documentReady = false;
    this.positioningInitialAnswer = false;
    const generation = ++this.readerGeneration;
    this.openedAnswerId = this.contentId;
    this.sequence = this.routeParams === undefined ? undefined : new AnswerSequence(this.routeParams);
    this.renderedIds = [];
    this.previousTask = undefined;
    this.nextTask = undefined;
    this.previousRetryAt = 0;
    this.nextRetryAt = 0;
    this.endMessage = '';
    this.endRetry = false;
    this.atFirstAnswer = false;
    this.atLastAnswer = false;
    this.jumpingAnswer = false;
    this.loadedAnswers.clear();
    this.followedAuthors.clear();
    const api = ZhihuApi.getInstance();
    let task: Promise<ZhihuContent>;
    if (this.kind === 'article') {
      task = api.fetchArticle(this.contentId);
    } else if (this.kind === 'pin') {
      task = api.fetchPin(this.contentId);
    } else {
      task = api.fetchAnswer(this.contentId);
    }
    task
      .then(async (content: ZhihuContent): Promise<void> => {
        if (generation !== this.readerGeneration) {
          return;
        }
        if (this.kind !== 'answer') {
          this.content = content;
          this.readActionState(content);
        }
        this.pageTitle = this.kind === 'pin' ? '想法' : (content.title || this.pageTitle);
        if (this.kind === 'answer' && this.questionId.length === 0) {
          this.questionId = content.questionId;
        }
        if (content.contentHtml.trim().length === 0) {
          throw new Error('知乎未返回正文，请重试');
        }
        if (this.kind === 'answer') {
          this.loadedAnswers.set(this.contentId, content);
          this.renderedIds = [this.contentId];
          if (this.questionId.length > 0) {
            await Promise.all([this.prefetchDirection(-1, PREVIOUS_BUFFER), this.prefetchDirection(1, NEXT_BUFFER)]);
          } else {
            this.showEndOfAnswers('暂未取得问题信息，无法接续回答');
          }
        }
        if (generation !== this.readerGeneration) {
          return;
        }
        this.documentHtml = this.buildDocument(content);
        this.applyDocument();
        HistoryStore.getInstance().record(getContext(this), this.kind, this.contentId, content.title)
          .catch((): void => {});
      })
      .catch((error: Error): void => {
        if (generation === this.readerGeneration) {
          this.isLoading = false;
          this.hasError = true;
          this.errorMessage = error.message;
        }
      });
  }

  private applyDocument(): void {
    if (!this.webReady || this.documentHtml.length === 0) {
      return;
    }
    try {
      loadReaderDocument(this.webController, this.documentHtml);
      if (this.kind !== 'answer') {
        this.isLoading = false;
      }
    } catch (error) {
      this.isLoading = false;
      this.hasError = true;
      this.errorMessage = '正文渲染失败，请重试';
    }
  }

  private async positionInitialAnswer(): Promise<void> {
    if (this.positioningInitialAnswer || this.documentReady || !this.documentHtml || this.hasError) {
      return;
    }
    this.positioningInitialAnswer = true;
    const generation = this.readerGeneration;
    const inset = this.getTitleInset();
    try {
      const source = '(() => {document.documentElement.style.setProperty("--reader-top-inset",' +
        JSON.stringify(inset + 'px') + ');if(!scrollToReaderAnswer(' + JSON.stringify(this.openedAnswerId) +
        ',' + inset + ',16))return "null";return JSON.stringify(readAnswerPosition(' + inset + ',' +
        this.getDockClearance() + '));})()';
      const position = this.parseAnswerPosition(await this.webController.runJavaScript(source));
      if (generation !== this.readerGeneration || this.hasError) {
        return;
      }
      if (position === null || position.id !== this.openedAnswerId) {
        throw new Error('无法定位初始回答');
      }
      this.lastReaderOffset = position.offset;
      this.initialReaderOffset = position.offset;
      this.titleDirectionAnchor = position.offset;
      this.adjustingScrollUntil = Date.now() + 180;
      this.webScrollOffset = Math.min(inset, Math.round(position.offset / 8) * 8);
      this.applyAnswerPosition(position);
      this.documentReady = true;
      this.isLoading = false;
    } catch (error) {
      if (generation === this.readerGeneration) {
        this.isLoading = false;
        this.hasError = true;
        this.errorMessage = '正文定位失败，请重试';
      }
    } finally {
      if (generation === this.readerGeneration) {
        this.positioningInitialAnswer = false;
      }
    }
  }

  private async toggleVote(content: ZhihuContent, direction: number): Promise<void> {
    if (!this.needsAccount() || this.voteRequests.has(content.id)) {
      return;
    }
    this.voteRequests.add(content.id);
    const next = content.voting === direction ? 0 : direction;
    const voteType = next === 1 ? 'up' : (next === -1 ? 'down' : 'neutral');
    const apiKind = this.kind === 'article' ? 'articles' : 'answers';
    const api = ZhihuApi.getInstance();
    try {
      let total: number | undefined;
      if (this.kind === 'answer') {
        total = await api.voteAnswer(content.id, voteType);
      } else {
        await api.voteContent(apiKind, content.id, voteType);
      }
      const delta = Number(next === 1) - Number(content.voting === 1);
      content.voting = next;
      content.voteupCount = total ?? Math.max(0, content.voteupCount + delta);
      this.refreshAnswerActions(content);
    } catch (error) {
      showToast(this.getUIContext(), '投票失败，请重试');
    } finally {
      this.voteRequests.delete(content.id);
    }
  }

  private openQuestion(): void {
    if (this.kind === 'answer' && this.questionId.length > 0) {
      const param: QuestionPageParam = { id: this.questionId };
      this.pathStack.pushPathByName('question', param);
    }
  }

  private writeAnswer(): void {
    if (this.questionId.length > 0) {
      openInBrowser(getContext(this), 'https://www.zhihu.com/question/' + encodeURIComponent(this.questionId));
    }
  }

  private needsAccount(): boolean {
    if (ZhihuSession.getInstance().isLoggedIn()) {
      return true;
    }
    showToast(this.getUIContext(), '请先登录');
    return false;
  }

  private readActionState(answer: ZhihuContent): void {
    this.voting = answer.voting;
    this.voteCount = answer.voteupCount;
    this.authorFollowed = answer.authorFollowed;
    this.favorited = answer.favorited;
    this.favoriteCount = answer.favoriteCount;
  }

  private refreshAnswerActions(answer: ZhihuContent): void {
    if (answer.id === this.content?.id) {
      this.readActionState(answer);
    }
    if (this.kind === 'answer' && this.documentReady) {
      const args = [
        JSON.stringify(answer.id), String(answer.voting), JSON.stringify(answerActionCount(answer.voteupCount)),
        JSON.stringify(answerVoteText(answer)), String(answer.authorFollowed),
        String(answer.favorited), JSON.stringify(answerActionCount(answer.favoriteCount))
      ];
      this.webController.runJavaScript('updateAnswerActions(' + args.join(',') + ')').catch((): void => {});
    }
  }

  private async toggleFollow(answer: ZhihuContent): Promise<void> {
    const token = answer.authorToken;
    if (!token || !this.needsAccount() || this.followRequests.has(token)) {
      return;
    }
    this.followRequests.add(token);
    try {
      const followed = !answer.authorFollowed;
      await ZhihuApi.getInstance().followPeople(encodeURIComponent(token), followed);
      this.followedAuthors.set(token, followed);
      this.loadedAnswers.forEach((neighbor: ZhihuContent): void => {
        if (neighbor.authorToken === token) {
          neighbor.authorFollowed = followed;
          this.refreshAnswerActions(neighbor);
        }
      });
    } catch (error) {
      showToast(this.getUIContext(), '关注操作失败，请重试');
    } finally {
      this.followRequests.delete(token);
    }
  }

  private showAnswerMenu(answer: ZhihuContent): void {
    this.getUIContext().getPromptAction().showActionMenu({
      buttons: [
        { text: '复制回答链接', color: APP_COLOR_TEXT },
        { text: '浏览器打开', color: APP_COLOR_TEXT }
      ]
    }).then(result => {
      if (result.index === 0) {
        copyToClipboard(this.getUIContext(), answer.shareUrl);
      } else if (result.index === 1) {
        openInBrowser(getContext(this), answer.shareUrl);
      }
    }).catch((): void => {});
  }

  private openAnswerCollections(answer: ZhihuContent): void {
    if (!this.needsAccount() || this.collectionSheetOpen) {
      return;
    }
    if (this.collectionUpdates.has(answer.id)) {
      showToast(this.getUIContext(), '收藏处理中');
      return;
    }
    this.collectionRequest++;
    this.collectionAnswer = answer;
    this.collectionChoices = [];
    this.nextCollectionPage = '';
    this.collectionBusy = false;
    this.collectionSheetOpen = true;
    this.loadAnswerCollections(false);
  }

  private async loadAnswerCollections(more: boolean): Promise<void> {
    const answer = this.collectionAnswer;
    if (answer === undefined || this.collectionBusy) {
      return;
    }
    const request = this.collectionRequest;
    const url = more ? this.nextCollectionPage : '';
    this.collectionBusy = true;
    this.collectionError = false;
    try {
      const page = await ZhihuApi.getInstance().fetchAnswerCollections(answer.id, url);
      if (request === this.collectionRequest) {
        const seen = new Set(this.collectionChoices.map((choice: ZhihuCollection): string => choice.id));
        this.collectionChoices = more ? this.collectionChoices.concat(page.items.filter(choice => !seen.has(choice.id))) :
          page.items;
        this.nextCollectionPage = page.nextUrl === url ? '' : page.nextUrl;
      }
    } catch (error) {
      if (request === this.collectionRequest) {
        this.collectionError = true;
      }
    } finally {
      if (request === this.collectionRequest) {
        this.collectionBusy = false;
      }
    }
  }

  private async toggleCollection(choice: ZhihuCollection): Promise<void> {
    const answer = this.collectionAnswer;
    if (answer === undefined || this.collectionBusy) {
      return;
    }
    const request = this.collectionRequest;
    const add = !choice.isFavorited;
    const choices = this.collectionChoices.slice();
    const moreCollections = this.nextCollectionPage.length > 0;
    this.collectionUpdates.add(answer.id);
    this.collectionBusy = true;
    try {
      await ZhihuApi.getInstance().setAnswerFavorite(answer.id, choice.id, add);
      choice.isFavorited = add;
      answer.favorited = choices.some(item => item.isFavorited === true) || (moreCollections && answer.favorited);
      answer.favoriteCount = Math.max(0, answer.favoriteCount + (add ? 1 : -1));
      this.refreshAnswerActions(answer);
      if (request === this.collectionRequest) {
        this.collectionChoices = choices;
        showToast(this.getUIContext(), add ? '已收藏' : '已移出收藏夹');
      }
    } catch (error) {
      showToast(this.getUIContext(), '收藏操作失败，请重试');
    } finally {
      this.collectionUpdates.delete(answer.id);
      if (request === this.collectionRequest) {
        this.collectionBusy = false;
      }
    }
  }

  @Builder
  answerCollectionSheet() {
    List() {
      ForEach(this.collectionChoices, (choice: ZhihuCollection) => {
        ListItem() {
          Row({ space: 12 }) {
            Text(choice.title).fontSize(16).fontColor(APP_COLOR_TEXT).layoutWeight(1)
            if (choice.isFavorited) {
              SymbolGlyph($r('sys.symbol.star_fill')).fontSize(19).fontColor([APP_COLOR_BLUE])
            }
          }
          .width('100%')
          .padding(16)
          .enabled(!this.collectionBusy)
          .onClick(() => { this.toggleCollection(choice); })
        }
      }, (choice: ZhihuCollection): string => choice.id + ':' + choice.isFavorited)
      if (this.collectionBusy) {
        ListItem() {
          LoadingView()
        }
      } else if (this.collectionError || this.nextCollectionPage.length > 0) {
        ListItem() {
          Button(this.collectionError ? '重试加载收藏夹' : '更多收藏夹')
            .margin(12)
            .onClick(() => { this.loadAnswerCollections(this.nextCollectionPage.length > 0); })
        }
      } else if (this.collectionChoices.length === 0) {
        ListItem() {
          Text('没有可用的收藏夹').padding(16).fontColor(APP_COLOR_SECONDARY)
        }
      }
    }
    .width('100%')
    .height('100%')
    .divider({ strokeWidth: 1, color: '#F0F0F0', startMargin: 16, endMargin: 16 })
  }

  private answerAction(answer: ZhihuContent, action: string): void {
    switch (action) {
      case 'author':
        this.openAuthor(answer);
        break;
      case 'share':
        copyToClipboard(this.getUIContext(), answer.shareUrl);
        break;
      case 'follow':
        this.toggleFollow(answer);
        break;
      case 'up':
        this.toggleVote(answer, 1);
        break;
      case 'down':
        this.toggleVote(answer, -1);
        break;
      case 'favorite':
        this.openAnswerCollections(answer);
        break;
      case 'comments':
        this.openComments(answer);
        break;
      case 'more':
        this.showAnswerMenu(answer);
        break;
      case 'retry':
        this.prefetchDirection(1, NEXT_BUFFER, true);
        break;
    }
  }

  private dockAnswerAction(action: string): void {
    const answer = this.loadedAnswers.get(this.content?.id ?? '');
    if (answer !== undefined) {
      this.answerAction(answer, action);
    }
  }

  private interceptAnswerAction(request: WebResourceRequest): boolean {
    const url = request.getRequestUrl();
    if (!url.startsWith(ANSWER_ACTION_ORIGIN)) {
      return false;
    }
    const match = /^(\d+)\/([a-z]+)$/.exec(url.substring(ANSWER_ACTION_ORIGIN.length));
    if (match && this.kind === 'answer' && this.documentReady && request.isMainFrame() && request.isRequestGesture()) {
      const answer = this.loadedAnswers.get(match[1]);
      if (answer !== undefined) {
        this.answerAction(answer, match[2]);
      }
    }
    return true;
  }

  private refreshAnswerEdges(): void {
    const id = this.content?.id ?? '';
    this.atFirstAnswer = this.sequence?.atEdge(id, -1) ?? false;
    this.atLastAnswer = this.sequence?.atEdge(id, 1) ?? false;
  }

  private prefetchAnswers(): void {
    if (!this.readerMoved) {
      return;
    }
    const active = this.renderedIds.indexOf(this.contentId);
    if (active < 0) {
      return;
    }
    if (this.questionId.length === 0) {
      this.showEndOfAnswers('暂未取得问题信息，无法接续回答');
      return;
    }
    this.prefetchDirection(-1, PREVIOUS_BUFFER - active);
    const dockIndex = this.renderedIds.indexOf(this.content?.id ?? '');
    this.prefetchDirection(1, NEXT_BUFFER - (this.renderedIds.length - Math.max(active, dockIndex) - 1));
  }

  private prefetchDirection(direction: number, count: number, retry: boolean = false): Promise<void> {
    const previous = direction < 0;
    const running = previous ? this.previousTask : this.nextTask;
    if (running !== undefined) {
      return running;
    }
    const anchor = this.renderedIds[previous ? 0 : this.renderedIds.length - 1];
    const retryAt = previous ? this.previousRetryAt : this.nextRetryAt;
    if (anchor === undefined || count <= 0 || this.sequence === undefined || this.questionId.length === 0 ||
      (!retry && Date.now() < retryAt)) {
      return Promise.resolve();
    }
    if (this.sequence.atEdge(anchor, direction)) {
      if (!previous) {
        this.showEndOfAnswers('已是最后一条回答');
      }
      return Promise.resolve();
    }
    const generation = this.readerGeneration;
    const work = this.fillAnswerBuffer(this.sequence, anchor, direction, count, generation)
      .catch((): void => {
        if (generation === this.readerGeneration) {
          if (previous) {
            this.previousRetryAt = Date.now() + PREFETCH_RETRY_DELAY;
          } else {
            this.nextRetryAt = Date.now() + PREFETCH_RETRY_DELAY;
            this.showEndOfAnswers('后续回答加载失败', true);
          }
        }
      })
      .finally((): void => {
        if (generation === this.readerGeneration) {
          if (previous) {
            this.previousTask = undefined;
          } else {
            this.nextTask = undefined;
          }
          this.refreshAnswerEdges();
        }
      });
    if (previous) {
      this.previousTask = work;
    } else {
      this.nextTask = work;
    }
    return work;
  }

  private async fetchNeighbor(id: string): Promise<ZhihuContent | null> {
    try {
      const answer = await ZhihuApi.getInstance().fetchAnswer(id);
      answer.authorFollowed = this.followedAuthors.get(answer.authorToken) ?? answer.authorFollowed;
      return answer.contentHtml.trim() ? answer : null;
    } catch (error) {
      const status = (error as ZhihuHttpError).status;
      if (status === 404 || status === 410) {
        return null;
      }
      throw new Error('回答加载失败');
    }
  }

  private async fillAnswerBuffer(sequence: AnswerSequence, anchor: string, direction: number, count: number,
    generation: number): Promise<void> {
    const ids = await sequence.neighbors(this.questionId, this.openedAnswerId, anchor, direction, count);
    if (generation !== this.readerGeneration) {
      return;
    }
    // Settle each fetch separately so a slow or failed answer cannot discard a ready neighbor.
    const requests = ids.map((id: string): Promise<ZhihuContent | null | undefined> =>
      this.fetchNeighbor(id).catch((): undefined => undefined));
    const batch: string[] = [];
    let failed = false;
    for (let i = 0; i < ids.length; i++) {
      const answer = await requests[i];
      if (generation !== this.readerGeneration) {
        return;
      }
      if (answer === undefined) {
        failed = true;
        break;
      }
      if (answer === null) {
        sequence.remove(ids[i]);
        continue;
      }
      this.loadedAnswers.set(ids[i], answer);
      batch.push(ids[i]);
      // Make the immediate neighbor available before waiting for the rest of the buffer.
      if (batch.length === 1 && i === 0 && ids.length > 1) {
        await this.insertAnswers(batch.splice(0), direction, generation);
      }
    }
    if (batch.length > 0) {
      await this.insertAnswers(batch, direction, generation);
    }
    if (generation !== this.readerGeneration) {
      return;
    }
    if (failed) {
      throw new Error('无法继续预加载回答');
    }
    const edge = this.renderedIds[direction < 0 ? 0 : this.renderedIds.length - 1];
    if (edge === anchor && !sequence.atEdge(anchor, direction)) {
      // Deleted or empty answers can be skipped without leaving the reader stuck.
      const remaining = await sequence.neighbors(this.questionId, this.openedAnswerId, anchor, direction, 1);
      if (remaining.length > 0 && generation === this.readerGeneration) {
        const content = await this.fetchNeighbor(remaining[0]);
        if (content !== null && generation === this.readerGeneration) {
          this.loadedAnswers.set(remaining[0], content);
          await this.insertAnswers(remaining, direction, generation);
        } else if (generation === this.readerGeneration) {
          sequence.remove(remaining[0]);
          throw new Error('下一条回答不可用');
        }
      }
    }
    if (direction > 0 && generation === this.readerGeneration) {
      const last = this.renderedIds[this.renderedIds.length - 1];
      this.showEndOfAnswers(sequence.atEdge(last, 1) ? '已是最后一条回答' : '正在预加载更多回答…');
    }
  }

  private async insertAnswers(ids: string[], direction: number, generation: number): Promise<void> {
    if (generation !== this.readerGeneration) {
      return;
    }
    const prepend = direction < 0;
    const batch = prepend ? ids.slice().reverse() : ids;
    if (this.documentReady) {
      if (prepend) {
        this.adjustingScrollUntil = Date.now() + 180;
      }
      const result = await this.webController.runJavaScript(
        'insertReaderAnswers(' + JSON.stringify(this.buildAnswerBatch(batch)) + ',' + prepend + ')');
      if (generation !== this.readerGeneration) {
        return;
      }
      if (result !== 'true') {
        batch.forEach((id: string): void => { this.loadedAnswers.delete(id); });
        throw new Error('无法接续正文');
      }
    }
    this.renderedIds = prepend ? batch.concat(this.renderedIds) : this.renderedIds.concat(batch);
    this.scheduleAnswerCheck();
  }

  private showEndOfAnswers(message: string, retry: boolean = false): void {
    if (message === this.endMessage && retry === this.endRetry) {
      return;
    }
    this.endMessage = message;
    this.endRetry = retry;
    if (!this.documentReady) {
      return;
    }
    const last = this.renderedIds[this.renderedIds.length - 1];
    const retryUrl = retry && last !== undefined ? ANSWER_ACTION_ORIGIN + last + '/retry' : '';
    this.webController.runJavaScript('(() => {const end=document.getElementById("reader-answer-end");' +
      'if(!end)return;end.textContent=' + JSON.stringify(message) + ';' +
      (retryUrl ? 'const link=document.createElement("a");link.textContent="重试";link.href=' +
        JSON.stringify(retryUrl) + ';end.append(" · ",link);' : '') + '})()').catch((): void => {});
  }

  private activateAnswer(id: string): void {
    const content = this.loadedAnswers.get(id);
    if (content === undefined || id === this.contentId) {
      return;
    }
    this.contentId = id;
    HistoryStore.getInstance().record(getContext(this), this.kind, id, content.title).catch((): void => {});
  }

  private selectDockAnswer(id: string | null, long: boolean): void {
    const answer = id === null ? undefined : this.loadedAnswers.get(id);
    this.longAnswer = long && answer !== undefined;
    if (answer?.id !== this.content?.id) {
      this.content = answer ?? null;
      if (answer !== undefined) {
        this.readActionState(answer);
      }
      this.refreshAnswerEdges();
    }
  }

  private async jumpAnswer(direction: number): Promise<void> {
    const dockId = this.content?.id;
    if (this.jumpingAnswer || !this.documentReady || dockId === undefined) {
      return;
    }
    this.jumpingAnswer = true;
    this.cancelAnswerCheck();
    try {
      let nextId = this.renderedIds[this.renderedIds.indexOf(dockId) + direction];
      if (nextId === undefined) {
        await this.prefetchDirection(direction, 1, true);
        nextId = this.renderedIds[this.renderedIds.indexOf(dockId) + direction];
      }
      if (nextId === undefined) {
        const atEdge = this.sequence?.atEdge(dockId, direction) ?? false;
        showToast(this.getUIContext(), atEdge ? (direction < 0 ? '已到本次阅读起点' : '已是最后一条回答') :
          '相邻回答暂未加载，请再试');
        return;
      }
      this.adjustingScrollUntil = Date.now() + 180;
      const result = await this.webController.runJavaScript(
        'scrollToReaderAnswer(' + JSON.stringify(nextId) + ',' + this.getTitleInset() + ',6)');
      if (result === 'true') {
        this.readerMoved = true;
        this.activateAnswer(nextId);
        await this.updateVisibleAnswer();
        this.prefetchAnswers();
      }
    } catch (error) {
      showToast(this.getUIContext(), '无法跳转到相邻回答，请重试');
    } finally {
      this.jumpingAnswer = false;
    }
  }

  private handleReaderScroll(offset: number): void {
    const current = Math.max(0, offset);
    this.lastReaderOffset = current;
    if (this.kind !== 'answer') {
      this.webScrollOffset = Math.min(this.getTitleInset(), Math.round(current));
      return;
    }
    if (!this.documentReady) {
      return;
    }
    if (Date.now() >= this.adjustingScrollUntil && Math.abs(current - this.initialReaderOffset) > 2) {
      this.readerMoved = true;
    }

    if (this.jumpingAnswer || Date.now() < this.adjustingScrollUntil) {
      this.titleDirectionAnchor = current;
    } else if (current <= 4) {
      this.compactAnswerTitle = false;
      this.titleDirectionAnchor = current;
    } else if (this.compactAnswerTitle) {
      this.titleDirectionAnchor = Math.max(this.titleDirectionAnchor, current);
      if (this.titleDirectionAnchor - current >= TITLE_DIRECTION_DISTANCE) {
        this.compactAnswerTitle = false;
        this.titleDirectionAnchor = current;
      }
    } else {
      this.titleDirectionAnchor = Math.min(this.titleDirectionAnchor, current);
      if (current - this.titleDirectionAnchor >= TITLE_DIRECTION_DISTANCE) {
        this.compactAnswerTitle = true;
        this.titleDirectionAnchor = current;
      }
    }
    if (!this.compactAnswerTitle) {
      this.webScrollOffset = Math.min(this.getTitleInset(), Math.round(current / 8) * 8);
    }
    this.scheduleAnswerCheck(this.crossedAnswerBoundary(current));
  }

  private crossedAnswerBoundary(offset: number): boolean {
    return offset < this.beforeAnswerOffset || offset >= this.afterAnswerOffset;
  }

  private scheduleAnswerCheck(crossingBoundary: boolean = false): void {
    if (!this.documentReady || this.kind !== 'answer') {
      return;
    }
    if (this.boundaryCheckPending) {
      return;
    }
    this.cancelAnswerCheck();
    this.boundaryCheckPending = crossingBoundary;
    // Read layout after settling or after crossing a known section boundary.
    this.answerCheckTimer = setTimeout((): void => {
      this.answerCheckTimer = -1;
      this.boundaryCheckPending = false;
      this.updateVisibleAnswer();
    }, crossingBoundary ? 40 : 120);
  }

  private cancelAnswerCheck(): void {
    if (this.answerCheckTimer >= 0) {
      clearTimeout(this.answerCheckTimer);
      this.answerCheckTimer = -1;
    }
    this.boundaryCheckPending = false;
  }

  aboutToDisappear(): void {
    this.readerGeneration++;
    this.cancelAnswerCheck();
    this.recheckPosition = false;
  }

  private getDockClearance(): number {
    return ANSWER_DOCK_HEIGHT + ANSWER_DOCK_BOTTOM_GAP + this.getUIContext().px2vp(this.bottomSafeAreaPx);
  }

  private parseAnswerPosition(result: string): AnswerPosition | null {
    const value = JSON.parse(result) as string | AnswerPosition | null;
    return typeof value === 'string' ? JSON.parse(value) as AnswerPosition | null : value;
  }

  private applyAnswerPosition(position: AnswerPosition): void {
    this.activateAnswer(position.id);
    this.selectDockAnswer(position.dockId, position.long);
    this.beforeAnswerOffset = position.before ?? Number.NEGATIVE_INFINITY;
    this.afterAnswerOffset = position.after ?? Number.POSITIVE_INFINITY;
  }

  private async updateVisibleAnswer(): Promise<void> {
    if (!this.documentReady || this.kind !== 'answer') {
      return;
    }
    if (this.checkingPosition) {
      this.recheckPosition = true;
      return;
    }
    this.checkingPosition = true;
    const generation = this.readerGeneration;
    const scrollOffset = this.lastReaderOffset;
    try {
      const result = await this.webController.runJavaScript(
        'JSON.stringify(readAnswerPosition(' + this.getTitleInset() + ',' + this.getDockClearance() + '))');
      if (generation === this.readerGeneration) {
        const position = this.parseAnswerPosition(result);
        if (position !== null && this.loadedAnswers.has(position.id)) {
          this.applyAnswerPosition(position);
          if (this.lastReaderOffset !== scrollOffset && this.crossedAnswerBoundary(this.lastReaderOffset)) {
            this.recheckPosition = true;
          }
        }
      }
    } catch (error) {
      // The Web component may be closing.
    } finally {
      this.checkingPosition = false;
      if (this.recheckPosition) {
        this.recheckPosition = false;
        this.scheduleAnswerCheck(true);
      }
      if (generation === this.readerGeneration) {
        this.prefetchAnswers();
      }
    }
  }

  private readerTitleOptions(): HdsNavigationTitleBarOptions {
    const answer = this.kind === 'answer';
    const compact = answer && this.compactAnswerTitle;
    const menu: HdsNavigationMenuItemOptions[] = [];
    if (answer && this.questionId.length > 0) {
      menu.push({
        content: {
          label: '写回答',
          icon: compact ? new SymbolGlyphModifier($r('sys.symbol.square_and_pencil')) : undefined,
          type: compact ? IconStyleMode.NORMAL : TextStyleMode.NORMAL,
          action: (): void => { this.writeAnswer(); }
        }
      });
    }
    if (compact && this.longAnswer) {
      menu.push({
        content: {
          label: '分享回答',
          icon: new SymbolGlyphModifier($r('sys.symbol.share')),
          action: (): void => { this.dockAnswerAction('share'); }
        }
      });
    }
    const options = spatialTitleBar({
      title: { mainTitle: '' },
      menu: menu.length > 0 ? { value: menu } : undefined,
      stackBuilder: (): void => this.readerTitle()
    }, this.getTitleInset(), compact ? 0 : this.webScrollOffset);
    if (answer && options.style?.originalStyle) {
      options.style.originalStyle.contentStyle = { menuStyle: { textColor: APP_COLOR_BLUE } };
    }
    return options;
  }

  @Builder
  readerTitle() {
    Row() {
      if (this.kind !== 'answer' || !this.compactAnswerTitle) {
        Text(this.pageTitle)
          .fontSize(18)
          .lineHeight(22)
          .fontWeight(this.kind === 'answer' ? FontWeight.Medium : FontWeight.Bold)
          .fontColor(APP_COLOR_TEXT)
          .layoutWeight(1)
          .maxLines(this.kind === 'answer' ? 1 : 2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .accessibilityDescription(this.kind === 'answer' ? '查看问题和全部回答' : '')
          .onClick(() => { this.openQuestion(); })
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 64, right: this.kind === 'answer' && this.questionId.length > 0 ? 108 : 16 })
    .hitTestBehavior(HitTestMode.Transparent)
  }

  build() {
    HdsNavDestination() {
      Stack() {
        Web({ src: 'about:blank', controller: this.webController, renderMode: RenderMode.ASYNC_RENDER })
          .width('100%')
          .height(LayoutPolicy.matchParent)
          .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM])
          .visibility(this.kind !== 'answer' && (this.isLoading || this.hasError) ? Visibility.Hidden : Visibility.Visible)
          .opacity(this.isLoading || this.hasError ? 0 : 1)
          .hitTestBehavior(this.isLoading || this.hasError ? HitTestMode.None : HitTestMode.Default)
          .verticalScrollBarAccess(this.kind !== 'answer')
          .onScroll((event: OnScrollEvent) => { this.handleReaderScroll(event.yOffset); })
          .onOverScroll(() => { this.scheduleAnswerCheck(); })
          .onSizeChange(() => { this.scheduleAnswerCheck(); })
          .onPageEnd((event) => {
            if (!this.webReady && event?.url === 'about:blank') {
              this.webReady = true;
              this.applyDocument();
            } else if (this.kind === 'answer' && this.documentHtml.length > 0 && !this.documentReady) {
              this.positionInitialAnswer();
            }
          })
          .onLoadIntercept((event) => this.interceptAnswerAction(event.data))
          .onErrorReceive((event) => {
            if (event?.request.isMainFrame()) {
              this.isLoading = false;
              this.hasError = true;
              this.errorMessage = '正文渲染失败，请重试';
            }
          })

        if (this.kind === 'answer' && this.compactAnswerTitle && this.statusBarHeightPx > 0) {
          Column()
            .width('100%')
            .height(this.getUIContext().px2vp(this.statusBarHeightPx) + 8)
            .position({ top: 0, left: 0 })
            .linearGradient({
              direction: GradientDirection.Bottom,
              colors: [['#F2FFFFFF', 0], ['#D9FFFFFF', 0.66], ['#00FFFFFF', 1]]
            })
            .hitTestBehavior(HitTestMode.None)
            .accessibilityLevel('no')
        }
        if (this.kind === 'answer' && this.content !== null && this.longAnswer && !this.isLoading && !this.hasError) {
          this.floatingAnswerControls()
        } else if (this.kind !== 'answer' && this.content !== null && !this.isLoading && !this.hasError) {
          Column({ space: 7 }) {
            if (this.readerMaterial !== undefined) {
              Tabs({ barPosition: BarPosition.End }) {
                TabContent().tabBar(this.authorPill(true))
              }
              .width('78%')
              .height(44)
              .barHeight(44)
              .scrollable(false)
              .divider(null)
              .barBackgroundColor(Color.Transparent)
              .barBackgroundBlurStyle(BlurStyle.NONE)
              .backgroundColor(Color.Transparent)
              .clip(false)
              .hitTestBehavior(HitTestMode.None)
            } else {
              this.authorPill(false)
            }
            if (this.readerMaterial !== undefined) {
              Tabs({ barPosition: BarPosition.End }) {
                TabContent().tabBar(this.readerActions(true))
              }
              .width('100%')
              .height(42)
              .barHeight(42)
              .scrollable(false)
              .divider(null)
              .barBackgroundColor(Color.Transparent)
              .barBackgroundBlurStyle(BlurStyle.NONE)
              .backgroundColor(Color.Transparent)
              .clip(false)
              .hitTestBehavior(HitTestMode.None)
            } else {
              this.readerActions(false)
            }
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding({ left: 12, right: 12, bottom: 8 })
          .position({ left: 0, bottom: 0 })
          .hitTestBehavior(HitTestMode.Transparent)
        }

        if (this.isLoading) {
          LoadingView()
        }
        if (this.hasError) {
          ErrorView({
            message: this.errorMessage,
            onRetry: (): void => {
              this.load();
            }
          })
        }
      }
      .width('100%')
      .height(LayoutPolicy.matchParent)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .backgroundColor('#FFFFFF')
      .bindSheet($$this.collectionSheetOpen, this.answerCollectionSheet(), {
        height: SheetSize.MEDIUM,
        title: { title: '收藏回答' }
      })
    }
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar(this.readerTitleOptions())
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .backgroundColor('#FFFFFF')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      const param = context.pathInfo.param as ContentPageParam;
      this.kind = param.kind;
      this.contentId = param.id;
      this.pageTitle = param.title;
      this.questionId = param.questionId ?? '';
      this.routeParams = param;
      if (this.kind !== 'answer' && this.kind !== 'article' && this.kind !== 'pin') {
        this.kind = 'answer';
      }
      this.load();
    })
  }

  @Builder
  floatingAnswerControls() {
    Column() {
      Column({ space: 8 }) {
        this.floatingArrow(-1, this.atFirstAnswer)
        this.floatingArrow(1, this.atLastAnswer)
        if (this.readerMaterial !== undefined) {
          Tabs({ barPosition: BarPosition.End }) {
            TabContent().tabBar(this.floatingAnswerDock(true))
          }
          .width('100%')
          .height(ANSWER_DOCK_HEIGHT)
          .barHeight(ANSWER_DOCK_HEIGHT)
          .scrollable(false)
          .divider(null)
          .barBackgroundColor(Color.Transparent)
          .barBackgroundBlurStyle(BlurStyle.NONE)
          .backgroundColor(Color.Transparent)
          .clip(false)
          .hitTestBehavior(HitTestMode.None)
        } else {
          this.floatingAnswerDock(false)
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: 460 })
      .alignItems(HorizontalAlign.End)
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .padding({ left: 12, right: 12, bottom: ANSWER_DOCK_BOTTOM_GAP })
    .position({ left: 0, bottom: 0 })
    .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  floatingArrow(direction: number, atEdge: boolean) {
    if (this.readerMaterial !== undefined) {
      Tabs({ barPosition: BarPosition.End }) {
        TabContent().tabBar(this.answerArrow(direction, atEdge, true))
      }
      .width(ANSWER_ARROW_SIZE)
      .height(ANSWER_ARROW_SIZE)
      .barHeight(ANSWER_ARROW_SIZE)
      .scrollable(false)
      .divider(null)
      .barBackgroundColor(Color.Transparent)
      .barBackgroundBlurStyle(BlurStyle.NONE)
      .backgroundColor(Color.Transparent)
      .clip(false)
      .hitTestBehavior(HitTestMode.None)
    } else {
      this.answerArrow(direction, atEdge, false)
    }
  }

  @Builder
  answerArrow(direction: number, atEdge: boolean, native: boolean) {
    Row() {
      Button() {
        SymbolGlyph(direction < 0 ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'))
          .fontSize(18)
          .fontColor([atEdge ? APP_COLOR_SECONDARY : APP_COLOR_TEXT])
          .opacity(atEdge ? 0.45 : 1)
      }
      .width(ANSWER_ARROW_SIZE)
      .height(ANSWER_ARROW_SIZE)
      .backgroundColor(Color.Transparent)
      .enabled(!atEdge && !this.jumpingAnswer)
      .accessibilityText(direction < 0 ? '上一个回答' : '下一个回答')
      .id(direction < 0 ? 'answer_previous' : 'answer_next')
      .onClick(() => { this.jumpAnswer(direction); })
    }
    .borderRadius(ANSWER_ARROW_SIZE / 2)
    .backgroundColor(native ? Color.Transparent : '#E6FFFFFF')
    .systemMaterial(native ? this.readerMaterial : undefined)
    .backdropBlur(native ? 0 : 22)
  }

  @Builder
  floatingAnswerDock(native: boolean) {
    Row() {
      if (this.content !== null) {
        Row({ space: 2 }) {
          Button() {
            Row({ space: 5 }) {
              if (this.content.authorAvatar) {
                Image(this.content.authorAvatar)
                  .width(30)
                  .height(30)
                  .borderRadius(15)
              } else {
                Circle({ width: 30, height: 30 }).fill('#EDF0F3')
              }
              Text(this.content.authorName || '匿名用户')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(APP_COLOR_TEXT)
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .layoutWeight(1)
          .height(44)
          .padding(0)
          .backgroundColor(Color.Transparent)
          .accessibilityDescription('查看回答作者')
          .onClick(() => { this.dockAnswerAction('author'); })

          if (this.content.authorToken) {
            Button(this.authorFollowed ? '已关注' : '+关注')
              .fontSize(12)
              .fontColor(this.authorFollowed ? APP_COLOR_SECONDARY : APP_COLOR_BLUE)
              .padding({ left: 2, right: 2 })
              .height(44)
              .backgroundColor(Color.Transparent)
              .onClick(() => { this.dockAnswerAction('follow'); })
          }
        }
        .layoutWeight(1)
      }
      this.dockIcon(null, '赞同', answerActionCount(this.voteCount), this.voting === 1, 'up')
      this.dockIcon(null, '反对', '', this.voting === -1, 'down')
      this.dockIcon(this.favorited ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'), '收藏',
        answerActionCount(this.favoriteCount), this.favorited, 'favorite')
      this.dockIcon($r('sys.symbol.message'), '评论', answerActionCount(this.content?.commentCount ?? 0), false, 'comments')
      this.dockIcon(null, '更多回答操作', '', false, 'more')
    }
    .width('100%')
    .height(ANSWER_DOCK_HEIGHT)
    .padding({ left: 9, right: 3 })
    .borderRadius(ANSWER_DOCK_HEIGHT / 2)
    .backgroundColor(native ? Color.Transparent : '#E6FFFFFF')
    .systemMaterial(native ? this.readerMaterial : undefined)
    .backdropBlur(native ? 0 : 22)
    .id('answer_action_dock')
  }

  @Builder
  dockIcon(icon: Resource | null, label: string, count: string, selected: boolean, action: string) {
    Button() {
      Stack() {
        if (icon !== null) {
          SymbolGlyph(icon).fontSize(ANSWER_ACTION_ICON_SIZE).fontColor([selected ? APP_COLOR_BLUE : APP_COLOR_TEXT])
        } else if (action === 'more') {
          Column({ space: 4 }) {
            Circle({ width: 4.5, height: 4.5 }).fill(APP_COLOR_TEXT)
            Circle({ width: 4.5, height: 4.5 }).fill(APP_COLOR_TEXT)
            Circle({ width: 4.5, height: 4.5 }).fill(APP_COLOR_TEXT)
          }
        } else {
          Shape() {
            Path({ commands: ANSWER_VOTE_PATH })
              .stroke(selected ? APP_COLOR_BLUE : APP_COLOR_TEXT)
              .strokeWidth('1.8px')
              .fill(selected ? APP_COLOR_BLUE : Color.Transparent)
          }
          .viewPort({ width: '24px', height: '24px' })
          .width(32)
          .height(32)
          .rotate({ angle: action === 'down' ? 180 : 0 })
        }
        if (count) {
          Text(count)
            .fontSize(10)
            .fontColor(selected ? APP_COLOR_BLUE : APP_COLOR_TEXT)
            .maxLines(1)
            .position({ left: ANSWER_DOCK_ACTION_WIDTH / 2 + ANSWER_ACTION_COUNT_OFFSET, top: 0 })
            .hitTestBehavior(HitTestMode.None)
        }
      }
      .width('100%')
      .height(40)
    }
    .width(action === 'more' ? 36 : ANSWER_DOCK_ACTION_WIDTH)
    .height(46)
    .padding(0)
    .backgroundColor(Color.Transparent)
    .accessibilityText(count ? label + ' ' + count : label)
    .onClick(() => { this.dockAnswerAction(action); })
  }

  @Builder
  readerActions(native: boolean) {
    Row({ space: 8 }) {
      Row() {
        Button(this.voting === 1 ? '已赞同 ' + this.voteCount : '赞同 ' + this.voteCount)
          .fontSize(14)
          .height(40)
          .fontColor(this.voting === 1 ? APP_COLOR_BLUE : APP_COLOR_TEXT)
          .backgroundColor(Color.Transparent)
          .onClick(() => { if (this.content !== null) { this.toggleVote(this.content, 1); } })
      }
      .height(40)
      .borderRadius(20)
      .backgroundColor(native ? Color.Transparent : (this.voting === 1 ? '#DEDAEAFF' : '#E6FFFFFF'))
      .systemMaterial(native ? this.readerMaterial : undefined)
      .backdropBlur(native ? 0 : 22)
      Blank()
      Row() {
        this.pillAction('评论' + ((this.content?.commentCount ?? 0) > 0 ? ' ' + this.content?.commentCount : ''),
          (): void => { if (this.content !== null) { this.openComments(this.content); } })
        this.pillAction('分享', (): void => { this.shareContent(); })
        this.pillAction('浏览器打开', (): void => { this.openInExternal(); })
      }
      .height(40)
      .padding({ left: 4, right: 4 })
      .borderRadius(20)
      .backgroundColor(native ? Color.Transparent : '#E6FFFFFF')
      .systemMaterial(native ? this.readerMaterial : undefined)
      .backdropBlur(native ? 0 : 22)
    }
    .width('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  authorPill(native: boolean) {
    if (this.content !== null) {
      Row({ space: 8 }) {
        if (this.content.authorAvatar.length > 0) {
          Image(this.content.authorAvatar).width(27).height(27).borderRadius(14)
        } else {
          Circle({ width: 27, height: 27 }).fill('#DDDDDD')
        }
        Column({ space: 2 }) {
          Text(this.content.authorName || '匿名用户')
            .fontSize(14)
            .fontColor(APP_COLOR_TEXT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.content.createdTime > 0) {
            Text('编辑于 ' + formatRelativeTime(this.content.createdTime))
              .fontSize(11)
              .fontColor(APP_COLOR_SECONDARY)
          }
        }
        .alignItems(HorizontalAlign.Start)
      }
      .constraintSize({ maxWidth: native ? '100%' : '80%' })
      .padding({ left: 8, right: 12, top: 5, bottom: 5 })
      .borderRadius(24)
      .backgroundColor(native ? Color.Transparent : '#E6FFFFFF')
      .systemMaterial(native ? this.readerMaterial : undefined)
      .backdropBlur(native ? 0 : 22)
      .onClick(() => {
        if (this.content !== null) {
          this.openAuthor(this.content);
        }
      })
      .alignSelf(ItemAlign.Start)
    }
  }

  @Builder
  pillAction(label: string, action: () => void) {
    Button(label)
      .height(40)
      .fontSize(12)
      .fontColor(APP_COLOR_TEXT)
      .backgroundColor(Color.Transparent)
      .padding({ left: 8, right: 8 })
      .onClick(() => { action(); })
  }

  private openAuthor(content: ZhihuContent): void {
    if (content.authorToken.length > 0) {
      const param: PeoplePageParam = { urlToken: content.authorToken };
      this.pathStack.pushPathByName('people', param);
    }
  }

  private openComments(content: ZhihuContent): void {
    const kind = this.kind === 'article' ? 'articles' : (this.kind === 'pin' ? 'pins' : 'answers');
    const param: CommentsPageParam = { kind: kind, id: content.id, title: this.pageTitle };
    this.pathStack.pushPathByName('comments', param);
  }

  private shareContent(): void {
    if (this.content === null) {
      return;
    }
    copyToClipboard(this.getUIContext(), this.content.shareUrl);
  }

  private openInExternal(): void {
    if (this.content === null) {
      return;
    }
    openInBrowser(getContext(this), this.content.shareUrl);
  }
}

@Builder
export function ContentBuilder() {
  ContentPage()
}
