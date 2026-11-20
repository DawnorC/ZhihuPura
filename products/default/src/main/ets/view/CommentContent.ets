import { COMMENT_EMOJIS } from './CommentEmojis';

export interface CommentTextPart {
  text: string;
  emoji?: ResourceStr;
}

export interface CommentContent {
  parts: CommentTextPart[];
  images: string[];
}

const HTML_ENTITIES: Record<string, string> = {
  'amp': '&', 'apos': "'", 'gt': '>', 'hellip': '…', 'lt': '<', 'nbsp': ' ', 'quot': '"', 'ndash': '–', 'mdash': '—'
};

function decodeEntities(value: string): string {
  return value.replace(/&(#(?:x[0-9a-f]+|\d+)|[a-z]+);/gi, (entity: string, name: string): string => {
    const key = name.toLowerCase();
    if (!key.startsWith('#')) {
      const character = HTML_ENTITIES[key];
      return typeof character === 'string' ? character : entity;
    }
    const hex = key.startsWith('#x');
    const code = Number.parseInt(key.substring(hex ? 2 : 1), hex ? 16 : 10);
    if (code > 0 && code <= 0x10ffff && (code < 0xd800 || code > 0xdfff)) {
      return String.fromCodePoint(code);
    }
    return entity;
  });
}

function attribute(tag: string, name: string): string {
  const pattern = new RegExp('\\s' + name + '\\s*=\\s*(?:"([^"]*)"|\'([^\']*)\'|([^\\s"\'`=<>]+))', 'i');
  const match = pattern.exec(tag);
  return decodeEntities(match?.[1] ?? match?.[2] ?? match?.[3] ?? '');
}

function imageUrl(value: string): string {
  const normalized = value.trim().replace(/^\/\//, 'https://').replace(/^http:\/\//i, 'https://');
  return /^https:\/\/(?:[a-z0-9-]+\.)*(?:zhimg|zhihu)\.com\/[^\s\\<>"']+$/i.test(normalized) ? normalized : '';
}

function appendImage(images: string[], url: string): void {
  if (url && !images.includes(url)) {
    images.push(url);
  }
}

function appendTextParts(parts: CommentTextPart[], source: string): void {
  const text = decodeEntities(source);
  const placeholders = /\[[^\[\]\r\n]{1,24}\]/g;
  let cursor = 0;
  let match: RegExpExecArray | null;
  while ((match = placeholders.exec(text)) !== null) {
    const label = match[0];
    const emoji = COMMENT_EMOJIS[label];
    if (!emoji) {
      continue;
    }
    if (match.index > cursor) {
      parts.push({ text: text.substring(cursor, match.index) });
    }
    parts.push({ text: label, emoji: emoji });
    cursor = match.index + label.length;
  }
  if (cursor < text.length) {
    parts.push({ text: text.substring(cursor) });
  }
}

export function parseCommentContent(html: string): CommentContent {
  const parts: CommentTextPart[] = [];
  const images: string[] = [];
  const source = html.replace(/<!--[^]*?-->|<(script|style|noscript)\b[^>]*>[^]*?<\/\1\s*>/gi, '');
  const tags = /<(\/?)([a-z][\w:-]*)(?:[^"'<>]|"[^"]*"|'[^']*')*>/gi;
  let text = '';
  let cursor = 0;
  let inAttachment = false;
  let match: RegExpExecArray | null;
  while ((match = tags.exec(source)) !== null) {
    if (!inAttachment) {
      text += source.substring(cursor, match.index);
    }
    cursor = tags.lastIndex;
    const tag = match[0];
    const closing = match[1] === '/';
    const name = match[2].toLowerCase();
    if (inAttachment) {
      if (closing && name === 'a') {
        inAttachment = false;
      }
      continue;
    }
    if (name === 'a' && !closing) {
      const classes = attribute(tag, 'class').toLowerCase().split(/\s+/);
      if (classes.includes('comment_img') || classes.includes('comment_gif') || classes.includes('comment_sticker')) {
        const url = imageUrl(attribute(tag, 'href'));
        if (url) {
          appendImage(images, url);
          inAttachment = true;
        }
      }
    } else if (name === 'img' && !closing) {
      const alt = attribute(tag, 'alt').trim();
      const localEmoji = COMMENT_EMOJIS[alt];
      const url = imageUrl(attribute(tag, 'data-original')) || imageUrl(attribute(tag, 'data-actualsrc')) ||
        imageUrl(attribute(tag, 'data-src')) || imageUrl(attribute(tag, 'src'));
      const className = attribute(tag, 'class');
      const inlineEmoji = localEmoji || (/\b(?:emoji|comment_emoji|emoticon)\b/i.test(className) ? url : '');
      if (inlineEmoji) {
        appendTextParts(parts, text);
        text = '';
        parts.push({ text: alt || '[表情]', emoji: inlineEmoji });
      } else if (url) {
        appendImage(images, url);
      } else {
        text += alt;
      }
    } else if (name === 'br' || (closing && (name === 'p' || name === 'div' || name === 'li'))) {
      text += '\n';
    }
  }
  if (!inAttachment) {
    text += source.substring(cursor);
  }
  appendTextParts(parts, text);
  if (parts.length > 0) {
    const first = parts[0];
    const last = parts[parts.length - 1];
    if (!first.emoji) {
      first.text = first.text.trimStart();
    }
    if (!last.emoji) {
      last.text = last.text.trimEnd();
    }
  }
  return { parts: parts.filter((part: CommentTextPart): boolean => part.text.length > 0), images: images };
}
