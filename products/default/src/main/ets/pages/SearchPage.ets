import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { pageTitleBar } from '../view/NavigationChrome';
/**
 * Search page, ported from SearchScreen.kt: TextInput + search_v3 results
 * (content results render as FeedCard, people results as user rows).
 */
import {
  ZhihuApi,
  ZhihuContentType,
  ZhihuFeedItem,
  ZhihuFeedPage,
  ZhihuHttpError,
  ZhihuSearchFilters
} from '@ohos/common';
import { FeedCard } from '../view/FeedCard';
import { loadSearchHistory, updateSearchHistory } from '../view/SearchHistory';
import { LoadingView, ErrorView, EmptyView } from '../view/Widgets';
import {
  PeoplePageParam,
  openFeedItem,
  showToast,
  APP_COLOR_BLUE,
  APP_COLOR_SECONDARY,
  APP_COLOR_TEXT,
  APP_COLOR_BG
} from '../view/NavHelper';

const TYPE_OPTIONS: SelectOption[] = [
  { value: '全部类型' }, { value: '回答' }, { value: '文章' }, { value: '视频' }
];
const TYPES: string[] = ['', 'answer', 'article', 'zvideo'];
const SORT_OPTIONS: SelectOption[] = [{ value: '综合排序' }, { value: '最新发布' }, { value: '最多赞同' }];
const SORTS: string[] = ['', 'created_time', 'upvoted_count'];
const TIME_OPTIONS: SelectOption[] = [
  { value: '不限时间' }, { value: '一天内' }, { value: '一周内' }, { value: '一个月内' },
  { value: '三个月内' }, { value: '半年内' }, { value: '一年内' }
];
const TIMES: string[] = ['', 'a_day', 'a_week', 'a_month', 'three_months', 'half_a_year', 'a_year'];

@Component
export struct SearchPage {
  pathStack: NavPathStack = new NavPathStack();
  @State query: string = '';
  @State items: ZhihuFeedItem[] = [];
  @State hasSearched: boolean = false;
  @State isLoading: boolean = false;
  @State hasError: boolean = false;
  @State errorMessage: string = '';
  @State loadingMore: boolean = false;
  @State typeIndex: number = 0;
  @State sortIndex: number = 0;
  @State timeIndex: number = 0;
  @State history: string[] = [];
  @State hotSearch: string[] = [];
  private nextUrl: string = '';
  private isEnd: boolean = false;
  private searchId: number = 0;
  private submittedQuery: string = '';

  private saveHistory(keyword: string): void {
    updateSearchHistory(getContext(this), keyword)
      .then((entries: string[]): void => { this.history = entries; })
      .catch((): void => { showToast(this.getUIContext(), '无法保存搜索历史'); });
  }

  private chooseKeyword(keyword: string): void {
    this.query = keyword;
    this.doSearch(keyword, true);
  }

  private doSearch(keyword: string, save: boolean = false): void {
    keyword = keyword.trim();
    if (keyword.length === 0) {
      return;
    }
    this.submittedQuery = keyword;
    if (save) {
      this.saveHistory(keyword);
    }
    const searchId = ++this.searchId;
    const filters: ZhihuSearchFilters = {
      type: TYPES[this.typeIndex], sort: SORTS[this.sortIndex], time: TIMES[this.timeIndex]
    };
    this.isLoading = true;
    this.loadingMore = false;
    this.hasError = false;
    this.hasSearched = true;
    this.nextUrl = '';
    ZhihuApi.getInstance().search(keyword, null, filters)
      .then((page: ZhihuFeedPage): void => {
        if (searchId !== this.searchId) {
          return;
        }
        this.items = page.items;
        this.nextUrl = page.nextUrl;
        this.isEnd = page.isEnd;
        this.isLoading = false;
      })
      .catch((error: ZhihuHttpError): void => {
        if (searchId !== this.searchId) {
          return;
        }
        this.isLoading = false;
        this.hasError = true;
        this.errorMessage = error.message;
      });
  }

  private loadMore(): void {
    if (this.loadingMore || this.isLoading || this.isEnd || this.nextUrl.length === 0) {
      return;
    }
    const searchId = this.searchId;
    const previousUrl = this.nextUrl;
    this.loadingMore = true;
    ZhihuApi.getInstance().search(this.submittedQuery, previousUrl)
      .then((page: ZhihuFeedPage): void => {
        if (searchId !== this.searchId) {
          return;
        }
        this.items = this.items.concat(page.items);
        this.nextUrl = page.nextUrl;
        this.isEnd = page.isEnd || page.nextUrl === previousUrl;
        this.loadingMore = false;
      })
      .catch((): void => {
        if (searchId === this.searchId) {
          this.loadingMore = false;
        }
      });
  }

  @Builder
  filter(options: SelectOption[], index: number, select: (index: number) => void) {
    Select(options)
      .selected(index)
      .value(options[index].value)
      .layoutWeight(1)
      .onSelect((next: number) => {
        select(next);
        this.doSearch(this.submittedQuery);
      })
  }

  @Builder
  keywordSection(title: string, entries: string[], clearable: boolean) {
    Row() {
      Text(title).fontSize(16).fontWeight(FontWeight.Medium)
      Blank()
      if (clearable) {
        Button('清空', { type: ButtonType.Normal })
          .fontColor(APP_COLOR_BLUE)
          .backgroundColor(Color.Transparent)
          .onClick(() => { this.saveHistory(''); })
      }
    }
    .width('100%')
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(entries, (keyword: string) => {
        Button(keyword)
          .fontSize(13)
          .fontColor(APP_COLOR_TEXT)
          .backgroundColor('#FFFFFF')
          .constraintSize({ maxWidth: '100%' })
          .margin({ right: 8, bottom: 8 })
          .onClick(() => { this.chooseKeyword(keyword); })
      }, (keyword: string): string => keyword)
    }
    .width('100%')
  }

  build() {
    HdsNavDestination() {
      Column() {
        Row({ space: 8 }) {
          TextInput({ placeholder: '搜索知乎内容', text: this.query })
            .fontSize(14)
            .height(36)
            .layoutWeight(1)
            .backgroundColor('#F0F0F0')
            .borderRadius(18)
            .onChange((value: string) => {
              this.query = value;
            })
            .onSubmit(() => {
              this.doSearch(this.query, true);
            })
          Button('搜索')
            .fontSize(14)
            .height(36)
            .backgroundColor(APP_COLOR_BLUE)
            .onClick(() => {
              this.doSearch(this.query, true);
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })

        Row({ space: 6 }) {
          this.filter(TYPE_OPTIONS, this.typeIndex, (index: number): void => { this.typeIndex = index; })
          this.filter(SORT_OPTIONS, this.sortIndex, (index: number): void => { this.sortIndex = index; })
          this.filter(TIME_OPTIONS, this.timeIndex, (index: number): void => { this.timeIndex = index; })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 })

        if (this.isLoading) {
          LoadingView()
            .layoutWeight(1)
        } else if (this.hasError) {
          ErrorView({
            message: this.errorMessage,
            onRetry: (): void => {
              this.doSearch(this.submittedQuery);
            }
          })
            .layoutWeight(1)
        } else if (!this.hasSearched) {
          if (this.history.length === 0 && this.hotSearch.length === 0) {
            EmptyView({ message: '输入关键词开始搜索' }).layoutWeight(1)
          } else {
            Scroll() {
              Column({ space: 12 }) {
                if (this.history.length > 0) {
                  this.keywordSection('搜索历史', this.history, true)
                }
                if (this.hotSearch.length > 0) {
                  this.keywordSection('知乎热搜', this.hotSearch, false)
                }
              }
              .width('100%')
              .padding(16)
            }
            .layoutWeight(1)
            .align(Alignment.Top)
          }
        } else if (this.items.length === 0) {
          EmptyView({ message: '没有找到相关内容' })
            .layoutWeight(1)
        } else {
          List() {
            ForEach(this.items, (item: ZhihuFeedItem, index: number) => {
              ListItem() {
                Column() {
                  if (item.contentType === ZhihuContentType.People) {
                    Row({ space: 12 }) {
                      if (item.authorAvatar.length > 0) {
                        Image(item.authorAvatar)
                          .width(44)
                          .height(44)
                          .borderRadius(22)
                          .backgroundColor('#EEEEEE')
                      } else {
                        Circle({ width: 44, height: 44 })
                          .fill('#DDDDDD')
                      }
                      Column({ space: 4 }) {
                        Text(item.title)
                          .fontSize(15)
                          .fontWeight(FontWeight.Medium)
                          .fontColor(APP_COLOR_TEXT)
                          .maxLines(1)
                        if (item.summary.length > 0) {
                          Text(item.summary)
                            .fontSize(13)
                            .fontColor(APP_COLOR_SECONDARY)
                            .maxLines(1)
                        }
                      }
                      .layoutWeight(1)
                      .alignItems(HorizontalAlign.Start)
                      Text('用户')
                        .fontSize(11)
                        .fontColor(APP_COLOR_BLUE)
                    }
                    .width('100%')
                    .alignItems(VerticalAlign.Center)
                    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                    .backgroundColor('#FFFFFF')
                    .onClick(() => {
                      const param: PeoplePageParam = { urlToken: item.authorToken };
                      this.pathStack.pushPathByName('people', param);
                    })
                  } else {
                    FeedCard({
                      item: item,
                      onOpen: (opened: ZhihuFeedItem): void => {
                        openFeedItem(this.pathStack, opened);
                      }
                    })
                  }
                  Divider()
                    .color('#F0F0F0')
                    .strokeWidth(1)
                    .margin({ left: 16 })
                }
              }
            }, (item: ZhihuFeedItem, index: number): string => item.id + '_' + item.contentType + '_' + index)
            if (this.loadingMore) {
              ListItem() {
                LoadingView({ label: '加载更多…' })
              }
            }
          }
          .width('100%')
          .layoutWeight(1)
          .backgroundColor(APP_COLOR_BG)
          .onReachEnd(() => {
            this.loadMore();
          })
        }
      }
      .width('100%')
      .height(LayoutPolicy.matchParent)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM])
      .backgroundColor(APP_COLOR_BG)
    }
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar(pageTitleBar('搜索'))
    .backgroundColor(APP_COLOR_BG)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      loadSearchHistory(getContext(this))
        .then((entries: string[]): void => { this.history = entries; })
        .catch((): void => {});
      ZhihuApi.getInstance().fetchHotSearch()
        .then((entries: string[]): void => { this.hotSearch = entries; })
        .catch((): void => {});
    })
  }
}

@Builder
export function SearchBuilder() {
  SearchPage()
}
