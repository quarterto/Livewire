require "./livewire"
	..get "/" ->"hello world"
	..get "/:name" ->"hello #{@params.name}"
	..get "/:name" ->"hello #{&1}"
	..listen 8000