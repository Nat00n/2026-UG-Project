

func tokenise(input: String) -> Array:
	var tokens = []
	var current = ""
	
	
	var array = input.split(" ", false)
	
	for i in range(len(array)):
		print(array[i])
		
	return array
