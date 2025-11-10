package blockchain

// Package blockchain 提供与区块链交互的占位接口，不含具体实现。

// Client 抽象区块链客户端。
type Client interface {
	// Subscribe 订阅事件（占位）。
	Subscribe(topic string) error
}
