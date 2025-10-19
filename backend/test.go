package main

import (
  "fmt"
  "net"
  "time"
)
func main() {
  conn, err := net.DialTimeout("tcp", "localhost:5432", 3*time.Second)
  if err != nil {
    fmt.Println("dial error:", err)
    return
  }
  conn.Close()
  fmt.Println("tcp OK")
}
