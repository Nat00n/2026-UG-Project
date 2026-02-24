

func tokenise(input):
	var array : Array = input.split().strip()
	
	for i in range(len(array)):
		print(array[i])
		
	return array
