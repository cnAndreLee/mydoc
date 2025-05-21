//go:build app1

package main

import (
	"fmt"
)

func main() {
	s := "LVIII"
	all := []byte{'I', 'V', 'X', 'L', 'C', 'D', 'M'}
	lMap := map[byte]int{
		'I': 1,
		'V': 5,
		'X': 10,
		'L': 50,
		'C': 100,
		'D': 500,
		'M': 1000,
	}

	index := -1
loop1:
	for i := len(all) - 1; i >= 0; i-- {
		for j := 0; j < len(s); j++ {
			if string(all[i]) == string(s[j]) {
				index = j
				break loop1
			}
		}
	}

	fmt.Println("index is :", index)

	sum := 0
	for n, _ := range s {
		if n < index {
			sum = sum + (-1 * lMap[s[n]])
		} else {
			sum += lMap[s[n]]
		}
	}
	fmt.Println(sum)
}
