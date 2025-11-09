package processor

// Package processor 负责对监听到的事件进行处理的接口与占位实现，不含具体逻辑。

// Processor 抽象事件处理器。
type Processor interface {
	// Handle 处理监听到的链上事件。
	Handle(event any) error
}
