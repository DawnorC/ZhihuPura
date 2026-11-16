import { formatCount, formatRelativeTime, ZhihuContent } from '@ohos/common';

export const ANSWER_ACTION_ORIGIN: string = 'https://answer-reader.zhihupura.invalid/';
export const ANSWER_ACTION_COUNT_OFFSET: number = 6;

export const ANSWER_DOCUMENT_STYLE: string = `
  .reader-answer {margin:0 -16px;padding:16px 16px 14px;}
  .reader-answer + .reader-answer {border-top:6px solid #f1f3f5;}
  .answer-byline {display:flex;align-items:center;gap:9px;min-height:44px;margin-bottom:10px;}
  .answer-author {display:flex;align-items:center;gap:11px;flex:1;min-width:0;color:#1a1a1a;}
  .answer-avatar {width:36px;height:36px;flex:0 0 36px;border-radius:50%;background:#edf0f3;object-fit:cover;}
  .answer-author-name {min-width:0;font-size:16px;font-weight:600;}
  .answer-author-name span {display:block;white-space:nowrap;text-overflow:ellipsis;overflow:hidden;}
  .answer-author-note {font-size:12px;font-weight:400;color:#8590a6;}
  .answer-follow {display:inline-flex;align-items:center;justify-content:center;min-height:38px;padding:0 14px;
    font-size:14px;font-weight:500;white-space:nowrap;background:#eef4ff;border-radius:20px;}
  .answer-follow[aria-pressed="true"] {background:#f5f6f8;color:#646d7b;}
  .answer-votes,.answer-date {color:#8590a6;font-size:13px;}
  .answer-votes {margin-bottom:12px;}
  .answer-date {display:block;margin:12px 0 7px;}
  .answer-body {display:flow-root;}
  .answer-tools {display:flex;align-items:center;gap:2px;margin-top:3px;}
  .answer-tools a,.answer-share {display:flex;align-items:center;justify-content:center;color:#373b42;}
  .answer-tools a:not(.answer-discuss) {width:44px;min-height:44px;}
  .answer-share {width:38px;min-height:44px;}
  .answer-tools a[aria-pressed="true"] {color:#0066ff;}
  .answer-tools a[aria-pressed="true"] svg {fill:#0066ff;}
  .answer-tools .answer-discuss {flex:1;min-width:0;height:38px;margin-right:8px;
    padding:0 9px;border-radius:20px;background:#f5f6f8;color:#737e90;font-size:13px;white-space:nowrap;}
  .answer-tools .answer-tool {position:relative;}
  .answer-tools .answer-count {position:absolute;top:3px;left:calc(50% + ${ANSWER_ACTION_COUNT_OFFSET}px);
    color:inherit;font-size:9px;line-height:12px;white-space:nowrap;pointer-events:none;}
  .answer-tools svg,.answer-share svg {width:21px;height:21px;flex:none;}
  #reader-answer-end {display:block;text-align:center;margin:12px 16px;color:#56677e;font-size:13px;}
  #reader-answer-end:empty {display:none;}
`;

export const ANSWER_DOCUMENT_SCRIPT: string = `
  function firstAnswerBelow(sections, line, getEdge) {
    let low = 0;
    let high = sections.length;
    while (low < high) {
      const middle = Math.floor((low + high) / 2);
      if (getEdge(sections[middle]) <= line) low = middle + 1;
      else high = middle;
    }
    return low;
  }

  function readAnswerPosition(inset, dockClearance) {
    const sections = document.querySelectorAll("body > .reader-answer");
    if (sections.length === 0) return null;
    const viewport = window.visualViewport;
    const scale = viewport?.scale ?? 1;
    const viewportTop = viewport?.offsetTop ?? 0;
    const readingLine = viewportTop + (inset + 24) / scale;
    const dockTop = viewportTop + (viewport?.height ?? innerHeight) - dockClearance / scale;
    const sectionTop = section => section.getBoundingClientRect().top;
    const authorBottom = section => section.firstElementChild.getBoundingClientRect().bottom;
    const readingIndex = Math.max(0, firstAnswerBelow(sections, readingLine, sectionTop) - 1);
    const nextDockIndex = firstAnswerBelow(sections, dockTop, authorBottom);
    const dock = sections[nextDockIndex - 1];

    // The reading position and dock change at different points while two answers are visible.
    const before = Math.max(
      readingIndex > 0 ? sectionTop(sections[readingIndex]) - readingLine : -Infinity,
      dock ? authorBottom(dock) - dockTop : -Infinity
    );
    const after = Math.min(
      readingIndex + 1 < sections.length ? sectionTop(sections[readingIndex + 1]) - readingLine : Infinity,
      nextDockIndex < sections.length ? authorBottom(sections[nextDockIndex]) - dockTop : Infinity
    );
    const offset = (window.scrollY + viewportTop) * scale;
    return {
      id: sections[readingIndex].dataset.answer,
      dockId: dock?.dataset.answer ?? null,
      long: !!dock && dock.getBoundingClientRect().height > innerHeight - inset - 20,
      before: Number.isFinite(before) ? offset + before * scale : null,
      after: Number.isFinite(after) ? offset + after * scale : null
    };
  }
  function updateAnswerActions(id, voting, voteCount, statText, following, favorite, favoriteCount) {
    const answer = document.getElementById("answer-" + id);
    if (!answer) return;
    answer.querySelector(".answer-votes").textContent = statText;
    answer.querySelector(".answer-up .answer-count").textContent = voteCount;
    answer.querySelector(".answer-up").setAttribute("aria-pressed", voting === 1);
    answer.querySelector(".answer-down").setAttribute("aria-pressed", voting === -1);
    const follow = answer.querySelector(".answer-follow");
    if (follow) {
      follow.setAttribute("aria-pressed", following);
      follow.textContent = following ? "已关注" : "+ 关注";
    }
    answer.querySelector(".answer-favorite").setAttribute("aria-pressed", favorite);
    answer.querySelector(".answer-favorite .answer-count").textContent = favoriteCount;
  }
`;

export const ANSWER_VOTE_PATH: string = 'M10.5 4.4a1.7 1.7 0 0 1 3 0l7.2 13.2a1.7 1.7 0 0 1-1.5 2.5H4.8a1.7 1.7 0 0 1-1.5-2.5z';
const UP_SHAPE: string = '<path d="' + ANSWER_VOTE_PATH + '"/>';
const DOWN_SHAPE: string = '<g transform="rotate(180 12 12)">' + UP_SHAPE + '</g>';
const STAR_SHAPE: string = '<path d="m12 2.9 2.8 5.8 6.4.9-4.6 4.5 1.1 6.4-5.7-3-5.7 3 1.1-6.4L2.8 9.6l6.4-.9z"/>';
const COMMENT_SHAPE: string = '<path d="M19.2 17a8.7 8.7 0 1 0-3.3 2.5l4.5 1.2z"/>';
const MORE_SHAPE: string = '<path d="M12 4h.01M12 12h.01M12 20h.01" stroke-width="3.5"/>';
const SHARE_SHAPE: string = '<path d="M14 4v4c-6.3.4-9.7 3.2-11 9 3-2.7 6-3.7 11-3.6V18l7-7z"/>';

function escapeHtml(text: string): string {
  return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function actionUrl(id: string, action: string): string {
  return ANSWER_ACTION_ORIGIN + encodeURIComponent(id) + '/' + action;
}

export function answerVoteText(content: ZhihuContent): string {
  return formatCount(content.voteupCount) + ' 人赞同了该回答';
}

export function answerActionCount(count: number): string {
  return count > 0 ? formatCount(count) : '';
}

function iconLink(id: string, action: string, cssClass: string, label: string, shape: string,
  count?: number, pressed?: boolean): string {
  const labelText = label + (count !== undefined && count > 0 ? ' ' + formatCount(count) : '');
  return '<a class="' + cssClass + '" href="' + actionUrl(id, action) + '" aria-label="' + labelText + '"' +
    (pressed === undefined ? '' : ' role="button" aria-pressed="' + pressed + '"') + '>' +
    '<svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" ' +
    'stroke-linecap="round" stroke-linejoin="round">' + shape + '</svg>' +
    (count === undefined ? '' : '<span class="answer-count">' + answerActionCount(count) + '</span>') + '</a>';
}

export function buildAnswerSection(id: string, answer: ZhihuContent): string {
  const name = escapeHtml(answer.authorName || '匿名用户');
  const avatar = /^https?:\/\//.test(answer.authorAvatar)
    ? '<img src="' + escapeHtml(answer.authorAvatar) + '" class="answer-avatar" width="36" height="36" alt="" loading="lazy">'
    : '<span class="answer-avatar"></span>';
  const author = avatar + '<span class="answer-author-name"><span>' + name + '</span>' +
    (answer.authorHeadline ? '<span class="answer-author-note">' + escapeHtml(answer.authorHeadline) + '</span>' : '') +
    '</span>';
  const authorLink = answer.authorToken ? '<a class="answer-author" href="' + actionUrl(id, 'author') + '">' +
    author + '</a>' : '<div class="answer-author">' + author + '</div>';
  const follow = answer.authorToken ? '<a class="answer-follow" href="' + actionUrl(id, 'follow') +
    '" role="button" aria-pressed="' + answer.authorFollowed + '">' + (answer.authorFollowed ? '已关注' : '+ 关注') + '</a>' : '';
  const date = answer.updatedTime || answer.createdTime;
  const dateText = (date > 0 ? formatRelativeTime(date) : '') +
    (answer.publishLocation ? (date > 0 ? ' · ' : '') + answer.publishLocation : '');
  return '<section class="reader-answer" id="answer-' + escapeHtml(id) + '" data-answer="' + escapeHtml(id) +
    '" aria-label="' + name + '的回答"><header class="answer-byline">' + authorLink + follow +
    iconLink(id, 'share', 'answer-share', '分享回答', SHARE_SHAPE) + '</header>' +
    '<div class="answer-votes">' + answerVoteText(answer) + '</div>' +
    '<div class="answer-body">' + answer.contentHtml + '</div>' +
    (dateText ? '<div class="answer-date">' + escapeHtml(dateText) + '</div>' : '') +
    '<footer class="answer-tools" aria-label="回答操作">' +
    '<a class="answer-discuss" href="' + actionUrl(id, 'comments') + '">一起聊一聊</a>' +
    iconLink(id, 'up', 'answer-tool answer-up', '赞同', UP_SHAPE, answer.voteupCount, answer.voting === 1) +
    iconLink(id, 'down', 'answer-tool answer-down', '反对', DOWN_SHAPE, undefined, answer.voting === -1) +
    iconLink(id, 'favorite', 'answer-tool answer-favorite', '收藏', STAR_SHAPE, answer.favoriteCount, answer.favorited) +
    iconLink(id, 'comments', 'answer-tool', '评论', COMMENT_SHAPE, answer.commentCount) +
    iconLink(id, 'more', 'answer-tool', '更多回答操作', MORE_SHAPE) + '</footer></section>';
}
