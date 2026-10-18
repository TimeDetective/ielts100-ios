# 课程数据格式

App 从 `IELTS100/Resources/lessons.json` 读取离线课程。根对象包含 `title`、`source`、`lessons`，可选 `dictionaryAttribution`。

每课字段：

| 字段 | 内容 |
| --- | --- |
| id | 从 1 开始连续递增的整数 |
| title / subtitle | 中文标题、副标题 |
| sentence / translation / grammar | 英文句子、中译、语法说明 |
| startPage / endPage | 来源页码；没有页码时均为 0 |
| exerciseAnswer | 出现在英文句子中的填空答案 |
| words | 词条数组 |
| glosses | 英文单词小写形式到释义对象的映射 |

词条包含 `id`（如 `1-1`，整个课程中唯一）、`word`、`ipa`（可为空）、`meaning`、`notes`（字符串数组）、`core`（布尔）、`group`、`page`。每课至少包含一个核心词条。

释义对象包含 `lemma`、`meaning`、`note` 和可选 `source`。每个句子中符合 `[A-Za-z]+(?:'[A-Za-z]+)?` 的英文单词都需要小写映射；同一单词只映射一次。单独词条、释义、例句等数据也需要具有合法使用与传播权利。

可选字段 `originalSentence`、`originalTranslation`、`correctionNote`、`correctionURL` 用于记录校订依据，不需要时可省略。课程来源必须如实标注。

仓库提供的演示文件就是完整示例，可复制其结构替换为自己的课程。运行 `python3 tools/validate_course.py` 后在模拟器检查查词、复习和填空。更换课程数据时请不要混用旧课程备份中的词条 ID。
