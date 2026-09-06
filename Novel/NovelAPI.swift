import Foundation

class NovelAPI {
    static let shared = NovelAPI()
    
    private let session = URLSession.shared
    
    // 常见搜索路径（用于自动探测）
    private let commonSearchPaths = [
        "/search.php?keyword=",
        "/search?keyword=",
        "/search?kw=",
        "/index.php?keyword=",
        "/book/search?keyword=",
        "/modules/article/search.php?searchkey=",
    ]
    
    // 搜索小说（聚合多个源）
    func searchNovels(keyword: String, sources: [NovelSource]) async throws -> [Novel] {
        var results: [Novel] = []
        
        await withTaskGroup(of: [Novel].self) { group in
            for source in sources {
                group.addTask {
                    do {
                        return try await self.searchFromSource(keyword: keyword, source: source)
                    } catch {
                        return []
                    }
                }
            }
            for await novels in group {
                results.append(contentsOf: novels)
            }
        }
        
        // 去重（按标题+作者）
        var seen = Set<String>()
        return results.filter { novel in
            let key = "\(novel.title)_\(novel.author)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }
    
    // 从单个源搜索（自动探测搜索路径）
    private func searchFromSource(keyword: String, source: NovelSource) async throws -> [Novel] {
        guard let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }
        
        // 尝试多个搜索路径
        let pathsToTry = [source.searchPath].compactMap { $0 } + commonSearchPaths.filter { $0 != source.searchPath }
        
        for searchPath in pathsToTry.prefix(3) {
            guard let url = URL(string: source.baseURL + searchPath + encodedKeyword) else { continue }
            
            do {
                let html = try await fetchHTML(url: url)
                let novels = parseSearchResults(html: html, source: source)
                if !novels.isEmpty {
                    return novels
                }
            } catch {
                continue
            }
        }
        
        return []
    }
    
    // 获取HTML
    private func fetchHTML(url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.setValue(url.host ?? "", forHTTPHeaderField: "Referer")
        request.setValue("1", forHTTPHeaderField: "Upgrade-Insecure-Requests")
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = true
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "NovelAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "无效响应"])
        }
        
        // 支持重定向
        if (300...399).contains(httpResponse.statusCode),
           let location = httpResponse.value(forHTTPHeaderField: "Location"),
           let redirectURL = URL(string: location, relativeTo: url) {
            return try await fetchHTML(url: redirectURL)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "NovelAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
        }
        
        // 尝试UTF-8
        if let html = String(data: data, encoding: .utf8) {
            return html
        }
        // 尝试GBK/GB18030
        let gbkEnc = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        if let html = String(data: data, encoding: String.Encoding(rawValue: gbkEnc)) {
            return html
        }
        // 尝试ASCII
        if let html = String(data: data, encoding: .ascii) {
            return html
        }
        
        return ""
    }
    
    // 解析搜索结果（通用）
    private func parseSearchResults(html: String, source: NovelSource) -> [Novel] {
        var novelList: [Novel] = []
        
        // 多种正则模式匹配搜索结果
        let patterns = [
            // 模式1: <div class="item">...<a href="...">标题</a>...<span>作者</span>
            "<div[^>]*class=\"[^\"]*item[^\"]*\"[^>]*>.*?<a[^>]*href=\"([^\"]+)\"[^>]*>([^<]+)</a>.*?<span[^>]*>([^<]*)</span>",
            // 模式2: <li>...<a href="..." title="...">...</a>
            "<li[^>]*>.*?<a[^>]*href=\"([^\"]+)\"[^>]*title=\"([^\"]+)\"[^>]*>.*?</a>.*?<span[^>]*>([^<]*)</span>",
            // 模式3: <tr>...<td class="odd"><a href="...">标题</a></td><td>作者</td>
            "<tr[^>]*>.*?<a[^>]*href=\"([^\"]+)\"[^>]*>([^<]+)</a>.*?<td[^>]*>([^<]*)</td>",
            // 模式4: 简单的<a href="/book/xxx">标题</a> - 作者
            "<a[^>]*href=\"(/book/[^\"]+)\"[^>]*>([^<]+)</a>[^<]*[-—][^<]*([^<\\n]+)",
            // 模式5: <div class="bookbox">...<h3><a href="...">标题</a></h3>...<p class="author">作者</p>
            "<h[34][^>]*>.*?<a[^>]*href=\"([^\"]+)\"[^>]*>([^<]+)</a>.*?</h[34]>.*?<p[^>]*class=\"[^\"]*author[^\"]*\"[^>]*>([^<]*)</p>",
            // 模式6: <dd><a href="...">标题</a></dd>
            "<dd[^>]*>.*?<a[^>]*href=\"([^\"]+)\"[^>]*>([^<]+)</a>.*?</dd>",
            // 模式7: <div class="result">...<a href="...">标题</a>...作者
            "<div[^>]*class=\"[^\"]*result[^\"]*\"[^>]*>.*?<a[^>]*href=\"([^\"]+)\"[^>]*>([^<]+)</a>.*?([^<]{2,20})",
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
                let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                for match in matches.prefix(20) {
                    if match.numberOfRanges >= 3 {
                        let bookUrl = (html as NSString).substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
                        let title = (html as NSString).substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces)
                        let author = (html as NSString).substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespaces)
                        
                        if !title.isEmpty && title.count > 1 && !title.contains("搜索") && !title.contains("首页") {
                            let fullUrl = bookUrl.hasPrefix("http") ? bookUrl : source.baseURL + (bookUrl.hasPrefix("/") ? "" : "/") + bookUrl
                            let novel = Novel(
                                id: "\(source.id)_\(fullUrl.hashValue)",
                                title: title,
                                author: author.isEmpty ? "未知" : author,
                                coverURL: nil,
                                intro: nil,
                                sourceId: source.id,
                                bookUrl: fullUrl,
                                lastChapter: nil,
                                updateTime: nil,
                                category: nil,
                                status: nil
                            )
                            novelList.append(novel)
                        }
                    }
                }
                if !novelList.isEmpty { break }
            }
        }
        
        return novelList
    }
    
    // 获取小说详情和章节列表
    func getNovelDetail(novel: Novel) async throws -> (Novel, [NovelChapter]) {
        // 示例小说：返回本地示例章节
        if novel.sourceId == "sample" {
            let chapters = (1...50).map { i in
                NovelChapter(id: "sample_chap_\(i)", title: "第\(i)章 示例章节\(i)", url: "sample://\(novel.id)/\(i)", index: i)
            }
            return (novel, chapters)
        }
        
        guard let url = URL(string: novel.bookUrl) else {
            throw NSError(domain: "NovelAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "无效URL"])
        }
        
        let html = try await fetchHTML(url: url)
        
        // 解析章节列表
        let chapters = parseChapterList(html: html, baseURL: novel.bookUrl, sourceId: novel.sourceId)
        
        // 解析详情
        let cover = parseCover(html: html)
        let intro = parseIntro(html: html)
        let updatedNovel = Novel(
            id: novel.id, title: novel.title, author: novel.author,
            coverURL: cover, intro: intro, sourceId: novel.sourceId,
            bookUrl: novel.bookUrl, lastChapter: chapters.last?.title,
            updateTime: nil, category: nil, status: nil
        )
        
        return (updatedNovel, chapters)
    }
    
    // 解析章节列表（通用）
    private func parseChapterList(html: String, baseURL: String, sourceId: String) -> [NovelChapter] {
        var chapters: [NovelChapter] = []
        
        // 找到章节列表区域（通常在id="list"或class="box_con"或<dl>中）
        var listHTML = html
        
        // 尝试提取章节列表区域
        let listPatterns = [
            "<div[^>]*id=\"list\"[^>]*>(.*?)</div>",
            "<div[^>]*class=\"[^\"]*box_con[^\"]*\"[^>]*>(.*?)</div>",
            "<dl[^>]*>(.*?)</dl>",
            "<div[^>]*class=\"[^\"]*chapter[^\"]*\"[^>]*>(.*?)</div>",
            "<ul[^>]*class=\"[^\"]*chapter[^\"]*\"[^>]*>(.*?)</ul>",
        ]
        
        for pattern in listPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
                if let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)) {
                    listHTML = (html as NSString).substring(with: match.range(at: 1))
                    break
                }
            }
        }
        
        // 匹配章节链接
        let chapterPatterns = [
            "<dd><a[^>]*href=\"([^\"]+)\"[^>]*>([^<]+)</a></dd>",
            "<li[^>]*><a[^>]*href=\"([^\"]+)\"[^>]*>([^<]+)</a></li>",
            "<a[^>]*href=\"(\\d+\\.html)\"[^>]*>([^<]+)</a>",
            "<a[^>]*href=\"(/\\d+/\\d+/\\d+\\.html)\"[^>]*>([^<]+)</a>",
            "<a[^>]*href=\"([^\"]*\\.html)\"[^>]*>(第[^<]+章[^<]*)</a>",
        ]
        
        for pattern in chapterPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
                let matches = regex.matches(in: listHTML, range: NSRange(listHTML.startIndex..., in: listHTML))
                for (index, match) in matches.enumerated() {
                    if match.numberOfRanges >= 3 {
                        let chapterUrl = (listHTML as NSString).substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
                        let title = (listHTML as NSString).substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces)
                        
                        if !title.isEmpty && title.count > 2 {
                            let fullUrl = chapterUrl.hasPrefix("http") ? chapterUrl : {
                                let base = (baseURL as NSString).deletingLastPathComponent
                                return chapterUrl.hasPrefix("/") ? (baseURL as NSString).deletingLastPathComponent + chapterUrl : base + "/" + chapterUrl
                            }()
                            
                            let chapter = NovelChapter(
                                id: "\(sourceId)_\(fullUrl.hashValue)",
                                title: title,
                                url: fullUrl,
                                index: index
                            )
                            chapters.append(chapter)
                        }
                    }
                }
                if chapters.count > 5 { break } // 至少找到5章才算成功
            }
        }
        
        return chapters
    }
    
    // 获取章节内容
    func getChapterContent(url: String) async throws -> ChapterContent {
        guard let chapterUrl = URL(string: url) else {
            throw NSError(domain: "NovelAPI", code: 2, userInfo: [NSLocalizedDescriptionKey: "无效章节URL"])
        }
        
        let html = try await fetchHTML(url: chapterUrl)
        return parseChapterContent(html: html)
    }
    
    // 解析章节内容（通用）
    private func parseChapterContent(html: String) -> ChapterContent {
        var title = ""
        var content = ""
        var prevUrl: String?
        var nextUrl: String?
        
        // 标题
        if let regex = try? NSRegularExpression(pattern: "<h1[^>]*>([^<]+)</h1>", options: []) {
            if let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)) {
                title = (html as NSString).substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            }
        }
        if title.isEmpty {
            if let regex = try? NSRegularExpression(pattern: "<title>([^<]+)</title>", options: []) {
                if let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)) {
                    title = (html as NSString).substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        // 内容（多种模式）
        let contentPatterns = [
            "<div[^>]*id=\"content\"[^>]*>(.*?)</div>",
            "<div[^>]*id=\"booktext\"[^>]*>(.*?)</div>",
            "<div[^>]*class=\"[^\"]*content[^\"]*\"[^>]*>(.*?)</div>",
            "<div[^>]*class=\"[^\"]*read-content[^\"]*\"[^>]*>(.*?)</div>",
            "<article[^>]*>(.*?)</article>",
            "<div[^>]*id=\"htmlContent\"[^>]*>(.*?)</div>",
        ]
        
        for pattern in contentPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
                if let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)) {
                    var raw = (html as NSString).substring(with: match.range(at: 1))
                    raw = raw.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
                    raw = raw.replacingOccurrences(of: "<p[^>]*>", with: "\n", options: .regularExpression)
                    raw = raw.replacingOccurrences(of: "</p>", with: "")
                    raw = raw.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    raw = raw.replacingOccurrences(of: "&nbsp;", with: " ")
                    raw = raw.replacingOccurrences(of: "&amp;", with: "&")
                    raw = raw.replacingOccurrences(of: "&lt;", with: "<")
                    raw = raw.replacingOccurrences(of: "&gt;", with: ">")
                    raw = raw.replacingOccurrences(of: "&quot;", with: "\"")
                    // 清理广告和多余空行
                    let lines = raw.components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty && !$0.contains("笔趣阁") && !$0.contains("www.biquge") && !$0.contains("记住") }
                    content = lines.joined(separator: "\n\n")
                    if !content.isEmpty { break }
                }
            }
        }
        
        // 上一章/下一章
        if let regex = try? NSRegularExpression(pattern: "<a[^>]*href=\"([^\"]+)\"[^>]*>上一章</a>", options: [.caseInsensitive]) {
            if let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)) {
                prevUrl = (html as NSString).substring(with: match.range(at: 1))
            }
        }
        if let regex = try? NSRegularExpression(pattern: "<a[^>]*href=\"([^\"]+)\"[^>]*>下一章</a>", options: [.caseInsensitive]) {
            if let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)) {
                nextUrl = (html as NSString).substring(with: match.range(at: 1))
            }
        }
        
        return ChapterContent(title: title, content: content, prevUrl: prevUrl, nextUrl: nextUrl)
    }
    
    // 解析封面
    private func parseCover(html: String) -> String? {
        let patterns = [
            "<img[^>]*id=\"cover\"[^>]*src=\"([^\"]+)\"",
            "<div[^>]*id=\"fmimg\"[^>]*>.*?<img[^>]*src=\"([^\"]+)\"",
            "<div[^>]*class=\"[^\"]*cover[^\"]*\"[^>]*>.*?<img[^>]*src=\"([^\"]+)\"",
            "<meta[^>]*property=\"og:image\"[^>]*content=\"([^\"]+)\"",
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
                if let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)) {
                    return (html as NSString).substring(with: match.range(at: 1))
                }
            }
        }
        return nil
    }
    
    // 解析简介
    private func parseIntro(html: String) -> String? {
        let patterns = [
            "<div[^>]*id=\"intro\"[^>]*>(.*?)</div>",
            "<div[^>]*class=\"[^\"]*intro[^\"]*\"[^>]*>(.*?)</div>",
            "<p[^>]*id=\"bookintro\"[^>]*>(.*?)</p>",
            "<meta[^>]*name=\"description\"[^>]*content=\"([^\"]+)\"",
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
                if let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)) {
                    var raw = (html as NSString).substring(with: match.range(at: 1))
                    raw = raw.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    raw = raw.replacingOccurrences(of: "&nbsp;", with: " ")
                    return raw.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return nil
    }
}
