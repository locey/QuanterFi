package logger

// Package logger 提供日志工具占位，不含具体实现。

// Logger 抽象日志器。
type Logger interface {
	Info(msg string)
	Error(msg string)
}
