const demos = {
  library: {
    label: "SKILL LIBRARY",
    title: "从一个入口查找所有 Skill",
    description: "统一检索本地、系统、项目和插件提供的 Skill，同时查看分类、健康状态、来源与源码摘要。",
    image: "/assets/skill-library.gif",
    alt: "Skill Manager 主面板中的 Skill 搜索和详情查看演示"
  },
  reference: {
    label: "CHAT-READY HANDOFF",
    title: "复制当前 AI 工具真正需要的格式",
    description: "在 Codex mention、Claude prompt、ChatGPT prompt、Cursor prompt、纯文本与自定义模板之间切换。",
    image: "/assets/skill-reference.gif",
    alt: "Skill Manager 为不同 AI 聊天工具复制 Skill 引用的演示"
  },
  notes: {
    label: "QUICK CONTEXT",
    title: "不离开当前任务，记下临时上下文",
    description: "在屏幕顶部附近记录 Markdown 备忘，让指令、判断和下一步继续留在正在进行的工作旁边。",
    image: "/assets/quick-notes.gif",
    alt: "Skill Manager 在刘海工作区记录 Markdown 临时笔记的演示"
  },
  files: {
    label: "LOCAL FILE SHELF",
    title: "让待使用的文件一直留在视线里",
    description: "把文件拖入短期暂存区，在 Finder、代码和聊天之间切换时保持可见，再拖出到下一步工作流。",
    image: "/assets/file-shelf.gif",
    alt: "Skill Manager 文件暂存区接收并保留拖入文件的演示"
  }
};

const tabs = [...document.querySelectorAll("[data-demo]")];
const panel = document.querySelector("#demo-panel");
const label = document.querySelector("#demo-label");
const title = document.querySelector("#demo-title");
const description = document.querySelector("#demo-description");
const image = document.querySelector("#demo-image");

function activateDemo(tab) {
  const demo = demos[tab.dataset.demo];
  tabs.forEach((item) => item.setAttribute("aria-selected", String(item === tab)));
  panel.setAttribute("aria-labelledby", tab.id);
  label.textContent = demo.label;
  title.textContent = demo.title;
  description.textContent = demo.description;
  image.src = demo.image;
  image.alt = demo.alt;
}

tabs.forEach((tab, index) => {
  tab.addEventListener("click", () => activateDemo(tab));
  tab.addEventListener("keydown", (event) => {
    if (!["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"].includes(event.key)) return;
    event.preventDefault();
    const offset = event.key === "ArrowLeft" || event.key === "ArrowUp" ? -1 : 1;
    const next = tabs[(index + offset + tabs.length) % tabs.length];
    next.focus();
    activateDemo(next);
  });
});
