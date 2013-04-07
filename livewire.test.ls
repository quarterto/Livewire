require! {
	Livewire: "./lib"
	buster
	buster.assertions
	http
	sync
	stream
}

{expect,assert} = assertions
async = (fn)->
	as = fn.async!
	(done)->
		as.call this, (err,r)->
			throw that if err?
			done!

async-get = (url,cb)->
	http.get url,(res)->
		body = []
		res.on \data body~push
		res.on \error cb
		res.on \end ->cb null {body: (Buffer.concat body)to-string \utf8} import res
	.on \error cb

get = (->async-get.sync null,...&).async!

buster.test-case "Livewire" {

	set-up: ->
		Livewire.log = id
		@server = http.create-server Livewire.app .listen 8000


	"fills in params": async ->
		Livewire.GET "/a/:b" ->"hello #{@params.b}"
		expect (get "http://localhost:8000/a/world")body .to-be "hello world"
		expect (get "http://localhost:8000/a/there")body .to-be "hello there"

	"unwinds chains": async ->
		Livewire.GET "/b/:c" [
			->"hello #{@params.c}"
			->"hello #{it.body.read!}"
		]
		expect (get "http://localhost:8000/b/world")body .to-be "hello hello world"

	"executes regexes": async ->
		Livewire.GET /^\/test\/(\w+)/, ->"test #{@params.0}"
		expect (get "http://localhost:8000/test/things")body .to-be "test things"

	"executes functions": async ->
		Livewire.GET ->
			if it.pathname.split '/' .1 is 'other' then a:"hello" else false
		, ->"other #{@params.a}"
		expect (get "http://localhost:8000/other")body .to-be "other hello"

	"gives 404s": async ->
		get "http://localhost:8000/rsnt"
			..body `assert.same` "404 /rsnt"
			..status-code `assert.same` 404

	"trailing slash implies prefix":
		"usually": async ->
			Livewire.GET "/noslash" -> "hello"
			Livewire.GET "/slash/" -> "hello"

			expect (get "http://localhost:8000/noslash/hello")status-code .to-be 404
			expect (get "http://localhost:8000/slash/hello")status-code .to-be 200
		"unless it's /": async ->
			Livewire.GET '/' -> "hello"
			expect (get "http://localhost:8000/trailer")status-code .to-be 404

	"the route gets passed in to the handler":
		"for strings": (done)->
			Livewire.GET "/my/awesome/:route" ->
				expect @route .to-be "/my/awesome/#{@params.route}"
				done!
				""
			get "http://localhost:8000/my/awesome/thing" ->

		"for regexes": (done)->
			Livewire.GET /^\/my\/regex\/thing$/, ->
				expect @route .to-be "/my/regex/thing"
				done!
				""
			get "http://localhost:8000/my/regex/thing" ->

		"for functions": (done)->
			Livewire.GET (.pathname is "/my/function/thing"), ->
				expect @route .to-be "/my/function/thing"
				done!
				""
			get "http://localhost:8000/my/function/thing" ->

	"handles responses of type":
		"string": async ->
			Livewire.GET "/response/type/string" -> "string response"
			expect (get "http://localhost:8000/response/type/string")body
			.to-be "string response"

		"buffer": async ->
			Livewire.GET "/response/type/buffer" -> new Buffer "buffer response"
			expect (get "http://localhost:8000/response/type/buffer")body
			.to-be "buffer response"

		"stream": async ->
			Livewire.GET "/response/type/stream" ->
				new class extends stream.Readable
					_read: -> if @push "stream response" then @push null
			expect (get "http://localhost:8000/response/type/stream")body
			.to-be "stream response"

		"error code": async ->
			Livewire.GET "/response/type/errorcode" -> Error 418
			get "http://localhost:8000/response/type/errorcode"
				..status-code `assert.same` 418
				..body `assert.same` "I'm a teapot"

		"error message": async ->
			Livewire.GET "/response/type/errormessage" -> Error "woah there!"
			get "http://localhost:8000/response/type/errormessage"
				..status-code `assert.same` 500
				..body `assert.same` "woah there!"


	tear-down: -> @server.close!

}