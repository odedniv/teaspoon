#= require teaspoon/reporters/html/base_view
#= require_self
#= require_tree ./html

class Teaspoon.Reporters.HTML extends Teaspoon.Reporters.BaseView

  constructor: ->
    @start = new Teaspoon.Date().getTime()
    @config = {"use-catch": true, "build-full-report": false, "display-progress": true}
    @total = {exist: 0, run: 0, passes: 0, failures: 0, skipped: 0}
    @views = {specs: {}, suites: {}}
    @filters = []
    @setFilters()
    @readConfig()
    super


  build: ->
    @buildLayout()

    @setText("env-info", @envInfo())
    @setText("version", Teaspoon.version)
    @findEl("toggles").onclick = @toggleConfig

    @findEl("suites").innerHTML = @buildSuiteSelect()
    @findEl("suite-select")?.onchange = @changeSuite

    @el = @findEl("report-all")

    @showConfiguration()
    @buildProgress()
    @buildFilters()


  reportRunnerStarting: (runner) ->
    @total.exist = runner.total || 0
    @setText("stats-duration", "...") if @total.exist


  reportRunnerResults: =>
    return unless @total.run
    @setText("stats-duration", @elapsedTime())
    @setStatus("passed") unless @total.failures
    @setText("stats-passes", @total.passes)
    @setText("stats-failures", @total.failures)
    if @total.run < @total.exist # For frameworks that don't "run" skipped specs
      @total.skipped = @total.exist - @total.run + @total.skipped
      @total.run = @total.exist
    @setText("stats-skipped", @total.skipped)
    @updateProgress()


  reportSuiteStarting: (suite) -> # noop


  reportSuiteResults: (suite) -> # noop


  reportSpecStarting: (spec) ->
    @reportView = new (Teaspoon.resolveClass("Reporters.HTML.SpecView"))(spec, @) if @config["build-full-report"]
    @specStart = new Teaspoon.Date().getTime()


  reportSpecResults: (spec) ->
    @total.run += 1
    @updateProgress()
    @updateStatus(spec)
    delete @reportView


  buildLayout: ->
    el = @createEl("div")
    el.id = "teaspoon-interface"
    el.innerHTML = (Teaspoon.resolveClass("Reporters.HTML")).template()
    document.body.appendChild(el)


  buildSuiteSelect: ->
    return "" if Teaspoon.suites.all.length == 1
    filename = ""
    filename = "/index.html" if /index\.html$/.test(window.location.pathname)
    options = []
    for suite in Teaspoon.suites.all
      path = [Teaspoon.root, suite].join("/")
      selected = if Teaspoon.suites.active == suite then " selected" else ""
      options.push("""<option#{selected} value="#{path}#{filename}">#{suite}</option>""")
    """<select id="teaspoon-suite-select">#{options.join("")}</select>"""


  buildProgress: ->
    @progress = Teaspoon.Reporters.HTML.ProgressView.create(@config["display-progress"])
    @progress.appendTo(@findEl("progress"))


  buildFilters: ->
    @setClass("filter", "teaspoon-filtered") if @filters.length
    @setHtml("filter-list", "<li>#{@filters.join("</li><li>")}", true)


  elapsedTime: ->
    "#{((new Teaspoon.Date().getTime() - @start) / 1000).toFixed(3)}s"


  updateStat: (name, value) ->
    return unless @config["display-progress"]
    @setText("stats-#{name}", value)


  updateStatus: (spec) ->
    elapsed = new Teaspoon.Date().getTime() - @specStart
    @reportView?.updateState(spec, elapsed)

    result = spec.result()

    if result.status == "pending"
      @updateStat("skipped", @total.skipped += 1)
    else if result.status == "failed"
      @updateStat("failures", @total.failures += 1)
      unless @config["build-full-report"]
        new (Teaspoon.resolveClass("Reporters.HTML.FailureView"))(spec).appendTo(@findEl("report-failures"))
      @setStatus("failed")
    else if result.skipped
      @updateStat("skipped", @total.skipped += 1)
    else
      @updateStat("passes", @total.passes += 1)


  updateProgress: ->
    @progress.update(@total.exist, @total.run)


  showConfiguration: ->
    @setClass(key, if value then "active" else "") for key, value of @config


  setStatus: (status) ->
    document.body.className = "teaspoon-#{status}"


  setFilters: ->
    @filters.push("by file: #{Teaspoon.params["file"]}") if Teaspoon.params["file"]
    @filters.push("by match: #{Teaspoon.params["grep"]}") if Teaspoon.params["grep"]


  readConfig: ->
    @config = config if config = @store("teaspoon")


  toggleConfig: (e) =>
    button = e.target
    return unless button.tagName.toLowerCase() == "button"
    name = button.getAttribute("id").replace(/^teaspoon-/, "")
    @config[name] = !@config[name]
    @store("teaspoon", @config)
    Teaspoon.reload()


  changeSuite: (e) =>
    options = e.target.options
    window.location.href = options[options.selectedIndex].value


  store: (name, value) ->
    if window.localStorage?.setItem?
      @localstore(name, value)
    else
      @cookie(name, value)


  cookie: (name, value = undefined) ->
    if value == undefined
      name = name.replace(/([.*+?^=!:${}()|[\]\/\\])/g, "\\$1")
      match = document.cookie.match(new RegExp("(?:^|;)\\s?#{name}=(.*?)(?:;|$)", "i"))
      match && JSON.parse(unescape(match[1]).split(" ")[0])
    else
      date = new Teaspoon.Date()
      date.setDate(date.getDate() + 365)
      document.cookie = "#{name}=#{escape(JSON.stringify(value))}; expires=#{date.toUTCString()}; path=/;"


  localstore: (name, value = undefined) ->
    if value == undefined
      JSON.parse(unescape(localStorage.getItem(name)))
    else
      localStorage.setItem(name, escape(JSON.stringify(value)))
