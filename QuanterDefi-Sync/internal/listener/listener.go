package listener

// Package listener 负责事件监听的接口与占位实现，不含具体逻辑。

// Listener 用于抽象链上事件监听器。
type Listener interface {
	// Start 用于启动监听（由 daemon 定时触发）。
	Start()
	// Stop 用于停止监听。
	Stop()
}
