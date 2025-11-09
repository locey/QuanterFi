package config

// Package config 提供配置结构体与加载占位，不含具体逻辑。

// Config 基础配置占位，仅用于结构展示。
type Config struct {
	// DaemonIntervalSeconds 定时监听间隔（秒）。
	DaemonIntervalSeconds int `yaml:"daemon_interval_seconds"`
	// Network 指定链网络名称。
	Network string `yaml:"network"`
}
