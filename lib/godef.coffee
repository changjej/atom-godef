proc = require 'child_process'
path = require 'path'
fs = require 'fs'
Q = require 'q'

{CompositeDisposable, TextEditor} = require 'atom'

module.exports = Godef =
  config:
      show:
        title: 'Show definition position'
        description: 'Choose one: Right, or New'
        type: 'string'
        default: 'New'
        enum: ['Right', 'New']
        order: 0
      goPath:
        title: 'GOPATH'
        description: 'You should set your GOPATH in the environment, and launch Atom using the `atom` command line tool; if you would like to set it explicitly, you can do so here (e.g. ~/go)'
        type: 'string'
        default: '' # This should usually be set in the environment, not here
        order: 1


  subscriptions: null

  activate: (state) ->
    @subscriptions = new CompositeDisposable

    atom.workspace.onDidChangeActivePaneItem (item) =>
      if item instanceof TextEditor
        item.scrollToCursorPosition()

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'godef:toggle': =>
      @find()


  deactivate: ->
    @subscriptions.dispose()

  serialize: ->

  find: ->
    textEditor = atom.workspace.getActiveTextEditor()
    grammar = textEditor?.getGrammar()

    if !grammar or grammar.name != 'Go'
      return

    wordEnd = textEditor.getSelectedBufferRange().end
    offset = new Buffer(textEditor.getTextInBufferRange([[0,0], wordEnd])).length
    @godef(textEditor.getPath(), offset, atom.config.get 'godef.show')

  expandPath: (p) ->
    # Code from github.com/joefitzgerald/go-plus
    unless p.indexOf('~') is -1
      home = process.env.HOME
      p = p.replace(/~/i, home)
    unless p.toUpperCase().indexOf('$HOME') is -1
      home = process.env.HOME
      p = p.replace(/\$HOME/i, home)
    return p


  godef: (file, offset, position) ->
    gopathConfig = atom.config.get('go-plus.goPath')
    result = gopathConfig if gopathConfig? and gopathConfig.trim() isnt ''
    result = result.replace('\n', '').replace('\r', '')
    if result != ''
      @gopath = @expandPath(result)
    else
      @gopath = process.env.GOPATH

    unless @gopath?
      console.log "GOPATH not found."
      @dispatch?.resetAndDisplayMessages(@editor, "GOPATH not found.")
      return

    console.log "GOPATH: " + @gopath

    found = false
    if not @godefpath?
      for p in @gopath.split(':')
        @godefpath = path.join(p, 'bin', 'godef')
        exists = fs.existsSync(@godefpath)
        if exists
            found = true
            break
        else
            continue

      if not found
        console.log "godef not find."
        return

    args = [
        @godefpath
        '-f'
        file
        '-o'
        offset
    ]

    proc.exec args.join(' '), (err, stdout, stderr) =>
      location = stdout.split(':')
      if location.length == 3
        row = parseInt(location[1])
        column = parseInt(location[2])
        options =
          initialLine: (--row)
          initialColumn: (--column)

        options.split = position.toLowerCase() if position != 'New'
        editor = atom.workspace.open(location[0], options)
