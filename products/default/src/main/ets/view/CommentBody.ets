import { APP_COLOR_TEXT } from './NavHelper';
import { CommentContent, CommentTextPart, parseCommentContent } from './CommentContent';

@Component
export struct CommentBody {
  @Prop @Watch('updateContent') content: string = '';
  @Prop fontSize: number = 15;
  @Prop lineHeight: number = 22;
  @Prop textColor: ResourceColor = APP_COLOR_TEXT;
  @State private body: CommentContent = { parts: [], images: [] };

  aboutToAppear(): void {
    this.updateContent();
  }

  private updateContent(): void {
    this.body = parseCommentContent(this.content);
  }

  build() {
    Column({ space: 8 }) {
      if (this.body.parts.length > 0) {
        Text() {
          ForEach(this.body.parts, (part: CommentTextPart) => {
            if (part.emoji) {
              ImageSpan(part.emoji)
                .width(this.fontSize + 4)
                .height(this.fontSize + 4)
                .objectFit(ImageFit.Contain)
                .verticalAlign(ImageSpanAlignment.CENTER)
            } else {
              Span(part.text)
            }
          }, (part: CommentTextPart, index: number): string =>
            index + ':' + part.text + ':' + (typeof part.emoji === 'string' ? part.emoji : ''))
        }
        .fontSize(this.fontSize)
        .fontColor(this.textColor)
        .lineHeight(this.lineHeight)
        .width('100%')
      }
      ForEach(this.body.images, (url: string) => {
        Image(url)
          .constraintSize({ maxWidth: 240, maxHeight: 180 })
          .objectFit(ImageFit.Contain)
          .borderRadius(8)
          .accessibilityText('评论图片')
      }, (url: string): string => url)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
