package main

import (
	"fmt"
	"sync"
)

func main() {
	// 创建channel
	numCh := make(chan int)

	var wg sync.WaitGroup

	// 使用结构体存储统计结果
	type result struct {
		count int
		sum   int
	}

	evenResult := result{}
	oddResult := result{}

	// 启动生成器协程
	go func() {
		defer close(numCh)
		for i := 1; i <= 100; i++ {
			numCh <- i
		}
	}()

	// 启动两个工作协程
	wg.Add(2)

	// 偶数统计协程
	go func() {
		defer wg.Done()
		for num := range numCh {
			if num%2 == 0 {
				evenResult.count++
				evenResult.sum += num
			}
		}
	}()

	// 奇数统计协程
	go func() {
		defer wg.Done()
		for num := range numCh {
			if num%2 != 0 {
				oddResult.count++
				oddResult.sum += num
			}
		}
	}()

	// 等待工作完成
	wg.Wait()

	// 打印结果
	fmt.Printf("偶数统计 - 数量: %d, 总和: %d\n", evenResult.count, evenResult.sum)
	fmt.Printf("奇数统计 - 数量: %d, 总和: %d\n", oddResult.count, oddResult.sum)
}
