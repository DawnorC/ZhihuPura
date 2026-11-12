/**
 * Feed card, ported from ui/components/FeedCard.kt (Compose).
 * Layout: source label / title / author row / summary / details + right thumbnail.
 */
import { ZhihuFeedItem, formatRelativeTime } from '@ohos/common';
import { APP_COLOR_BLUE, APP_COLOR_SECONDARY, APP_COLOR_TEXT, APP_COLOR_DIVIDER } from './NavHelper';

const AVATAR_BG_COLORS: string[] = ['#0066FF', '#EC4141', '#F5A623', '#33CC99', '#8B6FE8'];

@Component
export struct FeedCard {
  item: ZhihuFeedItem = new ZhihuFeedItem();
  onOpen: (item: ZhihuFeedItem) => void = (item: ZhihuFeedItem): void => {
  };

  private avatarBgColor(): string {
    let hash = 0;
    const seed = this.item.authorName.length > 0 ? this.item.authorName : this.item.id;
    for (let i = 0; i < seed.length; i++) {
      hash = (hash * 31 + seed.charCodeAt(i)) % 997;
    }
    return AVATAR_BG_COLORS[hash % AVATAR_BG_COLORS.length];
  }

  build() {
    Row({ space: 12 }) {
      Column({ space: 6 }) {
        if (this.item.actionText.length > 0) {
          Text(this.item.actionText)
            .fontSize(11)
            .fontColor(APP_COLOR_BLUE)
            .maxLines(1)
        }
        if (this.item.title.length > 0) {
          Text(this.item.title)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(APP_COLOR_TEXT)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .lineHeight(22)
        }
        Row({ space: 6 }) {
          if (this.item.authorAvatar.length > 0) {
            Image(this.item.authorAvatar)
              .width(20)
              .height(20)
              .borderRadius(10)
              .backgroundColor(this.avatarBgColor())
              .autoResize(true)
              .alt(this.avatarBgColor())
          } else {
            Circle({ width: 20, height: 20 })
              .fill(this.avatarBgColor())
          }
          Text(this.item.authorName.length > 0 ? this.item.authorName : '匿名用户')
            .fontSize(13)
            .fontColor(APP_COLOR_TEXT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.item.badgeTitle.length > 0) {
            Text(this.item.badgeTitle)
              .fontSize(10)
              .fontColor(APP_COLOR_BLUE)
              .maxLines(1)
          }
        }
        .width('100%')

        if (this.item.summary.length > 0) {
          Text(this.item.summary)
            .fontSize(14)
            .fontColor('#444444')
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .lineHeight(20)
        }
        Row({ space: 8 }) {
          Text(this.item.details)
            .fontSize(12)
            .fontColor(APP_COLOR_SECONDARY)
            .maxLines(1)
            .layoutWeight(1)
          if (this.item.createdTime > 0) {
            Text(formatRelativeTime(this.item.createdTime))
              .fontSize(12)
              .fontColor(APP_COLOR_SECONDARY)
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.item.thumbnailUrl.length > 0) {
        Image(this.item.thumbnailUrl)
          .width(68)
          .height(68)
          .borderRadius(6)
          .objectFit(ImageFit.Cover)
          .backgroundColor('#EEEEEE')
          .autoResize(true)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor('#FFFFFF')
    .onClick(() => {
      this.onOpen(this.item);
    })
  }
}

@Component
export struct CardDivider {
  build() {
    Divider()
      .color(APP_COLOR_DIVIDER)
      .strokeWidth(1)
      .margin({ left: 16 })
  }
}
