class SpokeGraph

	constructor: (@options = {}) ->

		self = @

		@nodes = []
		@links = []

		defaults =
			numSpokes: 6
			numLayers: 6
			generateCenter: false 
			nodeFunc: (data, dispose) ->
				console.log 'node', data
				data
			linkFunc: (a, b) ->
				console.log 'link', a, b
				a: a
				b: b

		@options[x] = @options[x] || defaults[x] for x of defaults

		prevLayer = null

		for layerNumber in [1..@options.numLayers] by 1
			prevLayer = @makeLayer layerNumber, prevLayer
			# layer.branches
			# @nodes = _.union @nodes, layer.nodes
			# @links = _.union @links, layer.links

		if @options.generateCenter
			do ->
				data = 
					numSpokes:		self.options.numSpokes
					numLayers:		self.options.numLayers
					layerNumber:	0
					spokeNumber:	0
					branchLength:	1
					branchIndex:	0
				nodeA = self.options.nodeFunc data, -> self.removeNode nodeA

				self.nodes.push nodeA

			for i in [0...@options.numSpokes] by 1
				nodeB = @nodes[i]
				@links.push @options.linkFunc nodeA, nodeB
			

	makeLayer: (layerNumber, prevLayer) ->
		# console.log "layer #{layerNumber}"
		nodes = []
		links = []
		branches = []

		for spokeNumber in [0...@options.numSpokes] by 1
			prevBranch = prevLayer.branches[spokeNumber] if prevLayer 
			branch = @makeBranch layerNumber, spokeNumber, prevBranch
			branches.push branch
			nodes = _.union nodes, branch.nodes
			links = _.union links, branch.links

		# Link branches in loop
		for branchA, i in branches
			branchB = branches[(i + 1) % branches.length]
			nodeA = _.last branchA.nodes
			nodeB = _.first branchB.nodes
			link = @options.linkFunc nodeA, nodeB
			links.push link
			@links.push link

		# Link branches to previous later of next spoke
		if prevLayer
			for branchA, i in branches
				branchB = prevLayer.branches[(i + 1) % prevLayer.branches.length]
				nodeA = _.last branchA.nodes
				nodeB = _.first branchB.nodes
				link = @options.linkFunc nodeA, nodeB
				links.push link
				@links.push link

		nodes: nodes
		links: links
		branches: branches


	makeBranch: (layerNumber, spokeNumber, prevBranch, length = layerNumber) ->

		self = @

		# console.log "layer #{layerNumber} branch #{spokeNumber}"
		nodes = []
		links = []

		# Create Branch Nodes
		for i in [0...length] by 1
			do ->
				data =
					numSpokes:		self.options.numSpokes
					numLayers:		self.options.numLayers
					layerNumber:	layerNumber
					spokeNumber:	spokeNumber
					branchLength:	length
					branchIndex:	i

				node = self.options.nodeFunc data, -> self.removeNode node
				nodes.push node
				self.nodes.push node

		# Link Branch Nodes
		for i in [0...nodes.length-1] by 1
			nodeA = nodes[i]
			nodeB = nodes[(i + 1) % nodes.length]
			link = @options.linkFunc nodeA, nodeB
			links.push link
			@links.push link

		# Link Branch with Previous Branch
		if prevBranch
			for nodeA, i in prevBranch.nodes
				nodeB = nodes[i]
				nodeC = nodes[i+1]
				link = @options.linkFunc nodeA, nodeB
				links.push link
				@links.push link
				link = @options.linkFunc nodeA, nodeC
				links.push link
				@links.push link

		removeNode: (node) ->
			@nodes = _.without @nodes, node
			@links = _.filter @links, (link) -> link.a isnt node and link.b isnt node


		nodes:	nodes
		links:	links

class MinefieldUnit

	constructor: ->
		@disposer = new Rx.CompositeDisposable
		@disposer.add @isCovered 	= new Rx.BehaviorSubject true
		@disposer.add @isBomb		= new Rx.BehaviorSubject false
		@disposer.add @isFlagged	= new Rx.BehaviorSubject false
		@disposer.add @flag			= new Rx.BehaviorSubject 'certain'
		@disposer.add @numBombs		= new Rx.BehaviorSubject 0
		@friends = []

	addFriend: (friend) ->
		self = @
		@friends.push friend
		@disposer.add friend.isBomb.skipWhile((x) -> not x).subscribe (x) ->
			self.numBombs.onNext self.numBombs.value + if x then 1 else -1

	dispose: ->
		@disposer.dispose()

class MinefieldLink

	constructor: (@a, @b) ->
		@a.unit.addFriend @b.unit
		@b.unit.addFriend @a.unit
		@spring = new Spring @a.particle, @b.particle, 40, 0.5
		@view = new MinefieldLinkView @

class MinefieldNode

	constructor: (data) ->
		@unit = new MinefieldUnit
		@particle = MinefieldNode.makeParticle data
		@view = new MinefieldNodeView @unit, @particle

	@makeParticle: (data) ->

		distance = data.layerNumber * 50

		a = do ->
			spokeAngle = data.spokeNumber / data.numSpokes * Math.PI * 2
			x = distance * Math.cos spokeAngle
			y = distance * Math.sin spokeAngle
			new Vector x, y

		b = do ->
			spokeAngle = (data.spokeNumber + 1) / data.numSpokes * Math.PI * 2
			x = distance * Math.cos spokeAngle
			y = distance * Math.sin spokeAngle
			new Vector x, y

		lerp = (a, b, amount) ->
			x = a.x + (b.x - a.x) * amount
			y= a.y + (b.y - a.y) * amount
			new Vector x, y

		particle = new Particle
		particle.pos = lerp a, b, data.branchIndex / data.branchLength
		particle

class MinefieldNodeView

	constructor: (@unit, @particle) ->

	draw: (ctx) ->

		ctx.shadowColor = 'black'
		ctx.shadowBlur = 0

		if not @unit.isCovered.value and @unit.numBombs.value is 0 and !@unit.isBomb.value
			return

		if @unit.isCovered.value
			if @unit.isFlagged.value
				ctx.fillStyle = 'rgba(255,255,255,1)'
				ctx.shadowBlur = 5
				ctx.shadowColor = 'rgba(125,125,255,1)'
			else
				ctx.fillStyle = 'rgba(0,0,0,0.15)'
		else
			ctx.fillStyle = 'rgba(255,255,255,1)'
		ctx.beginPath()
		ctx.arc(@particle.pos.x, @particle.pos.y, @particle.mass * 15, 0, Math.PI * 2)
		ctx.fill()
		ctx.shadowBlur = 0

		if @unit.isCovered.value
			if @unit.isFlagged.value
				ctx.fillStyle = 'rgba(125,125,255,1)'
			else
				ctx.fillStyle = 'rgba(255,255,255,1)'
		else if @unit.isBomb.value
			ctx.fillStyle = 'rgba(0,0,0,1)'

		else
			ctx.fillStyle = 'rgba(255,255,255,1)'

		ctx.beginPath()
		ctx.arc(@particle.pos.x, @particle.pos.y, @particle.mass * 10, 0, Math.PI * 2)
		ctx.fill()

		if @unit.numBombs.value > 0 and not @unit.isBomb.value and not @unit.isCovered.value
			text = @unit.numBombs.value.toString()
			xOffset = ctx.measureText(text).width / 2
			ctx.textBaseline = "middle";
			ctx.font = '12pt sans-serif'
			ctx.fillStyle = 'rgba(0,0,0,0.5)'
			ctx.fillText text, @particle.pos.x - xOffset, @particle.pos.y+1

class MinefieldLinkView

	constructor: (@link) ->

	draw: (ctx) ->

		p1 = @link.a.particle
		p2 = @link.b.particle

		if @link.a.unit.isCovered.value or @link.b.unit.isCovered.value or @link.a.unit.isBomb.value or @link.b.unit.isBomb.value
			ctx.strokeStyle = 'rgba(0, 0, 0, 0.15)'
			ctx.beginPath()
			ctx.moveTo p1.pos.x, p1.pos.y
			ctx.lineTo p2.pos.x, p2.pos.y
			ctx.stroke()

class Minefield

	constructor: (@graph, @numMines = 10) ->

		self = @

		@reveals = Rx.Observable.empty()

		for node in graph.nodes
			do ->
				a = node
				self.reveals = self.reveals.merge node.unit.isCovered.where((x)->!x).select -> a

		disposer = new Rx.CompositeDisposable

		disposer.add @reveals.take(1).subscribe (node) ->
			units = _.map self.graph.nodes, (node) -> node.unit
			units = _.without units, node.unit
			units = _.difference units, node.unit.friends
			units = _.shuffle units
			units = _.first units, self.numMines
			unit.isBomb.onNext true for unit in units

		disposer.add @reveals
			.where((node) -> node.unit.numBombs.value == 0)
			.delay(25)
			.subscribe (node) ->
				units = _.filter node.unit.friends, (friend) -> friend.isCovered.value
				unit.isCovered.onNext false for unit in units

		disposer.add @reveals
			.where((node) -> node.unit.isBomb.value)
			.delay(100)
			.subscribe ->
				disposer.dispose()
				alert 'YOU LOSE'

		# @reveals.delay(25).subscribe (node) ->
			
		# 	unit.isCovered.onNext false for unit in units
		# 	if node.unit.numBombs.value == 0
		# 		graph.nodes = _.without graph.nodes, node
		# 		graph.links = _.filter graph.links, (link) -> link.a != node and link.b != node

$ ->

	do ->

		release = $(document).onAsObservable 'mouseup'

		jQuery.fn.tapAsObservable = ->
			target = $ @
			target.onAsObservable('mousedown').selectMany (e) ->
				target.onAsObservable('mouseup')
					.select(->e)
					.take(1)
					.takeUntil Rx.Observable.interval 250

		jQuery.fn.longPressAsObservable = ->
			target = $ @
			target.onAsObservable('mousedown').selectMany (e) ->
				Rx.Observable.returnValue(e)
					.delay(250)
					.takeUntil release

$ ->

	$window = $ window

	$window.onAsObservable('resize').subscribe ->
		$('canvas').attr
			width: $window.width()
			height: $window.height()

	$window.resize()

	physics = new Physics

	graph = null

	do ->
		graph = new SpokeGraph
			numSpokes: 10
			numLayers: 7
			nodeFunc: (data) -> new MinefieldNode data
			linkFunc: (a, b) -> new MinefieldLink a, b

		for node in graph.nodes
			particle = node.particle
			physics.particles.push particle

		for link in graph.links
			spring = link.spring
			physics.springs.push spring

	field = new Minefield graph, 40

	getClosestNode = (nodes, pos) ->
		pos = new Vector pos.x - $(window).width() / 2, pos.y - $(window).height() / 2
		nodes = _.sortBy nodes, (node) ->
			dist = node.particle.pos.dist pos
			dist
		nodes[0]

	# $('canvas').onAsObservable('mousemove')
	# 	.select((e) -> new Vector e.pageX, e.pageY)
	# 	.select((pos) -> getClosestNode graph.nodes, pos)
	# 	.subscribe (node) ->

	$('canvas').tapAsObservable()
		.select((e) -> new Vector e.pageX, e.pageY)
		.select((pos) -> getClosestNode graph.nodes, pos)
		.where((node) -> !node.unit.isFlagged.value)
		.subscribe (node) ->
			node.unit.isCovered.onNext false

	$('canvas').tapAsObservable()
		.select((e) -> new Vector e.pageX, e.pageY)
		.select((pos) -> getClosestNode graph.nodes, pos)
		.where((node) -> !node.unit.isCovered.value)
		.where((node) -> node.unit.numBombs.value > 0)
		.where((node) ->
			flags = _.filter node.unit.friends, (friend) -> friend.isFlagged.value
			node.unit.numBombs.value is flags.length
			)
		.subscribe (node) ->
			nonBombFriends = _.filter node.unit.friends, (friend) -> !friend.isFlagged.value
			_.each nonBombFriends, (friend) -> friend.isCovered.onNext false

	$('canvas').longPressAsObservable()
		.select((e) -> new Vector e.pageX, e.pageY)
		.select((pos) -> getClosestNode graph.nodes, pos)
		.subscribe (node) ->
			node.unit.isFlagged.onNext !node.unit.isFlagged.value



	canvas = $('canvas')[0]
	ctx = canvas.getContext '2d'
	t = 0

	update = (timestamp) ->

		dt = (timestamp - t) / 1000
		t = timestamp

		return requestAnimationFrame update if not isFinite dt

		ctx.setTransform 1, 0, 0, 1, 0, 0;
		ctx.clearRect 0, 0, canvas.width, canvas.height
		ctx.translate $window.width() / 2, $window.height() / 2

		physics.step()

		for link in graph.links
			link.view.draw ctx

		for node in graph.nodes
			node.view.draw ctx

		requestAnimationFrame update

	update()