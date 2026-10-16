package main

// Desktop notifications for new texts. Clicking one opens the conversation
// in the panel.

import (
	"fmt"
	"os"
	"os/exec"
	"sync"

	"github.com/godbus/dbus/v5"
)

type notifier struct {
	mu    sync.Mutex
	conn  *dbus.Conn
	convs map[uint32]string // notification ID -> conversation
	last  map[string]uint32 // conversation -> its latest notification (replaced, not stacked)
}

func newNotifier() *notifier {
	n := &notifier{convs: map[uint32]string{}, last: map[string]uint32{}}
	conn, err := dbus.ConnectSessionBus()
	if err != nil {
		fmt.Fprintln(os.Stderr, "notifications disabled:", err)
		return n
	}
	n.conn = conn
	_ = conn.AddMatchSignal(dbus.WithMatchInterface("org.freedesktop.Notifications"), dbus.WithMatchMember("ActionInvoked"))
	_ = conn.AddMatchSignal(dbus.WithMatchInterface("org.freedesktop.Notifications"), dbus.WithMatchMember("NotificationClosed"))
	signals := make(chan *dbus.Signal, 16)
	conn.Signal(signals)
	go func() {
		for sig := range signals {
			if len(sig.Body) < 1 {
				continue
			}
			id, _ := sig.Body[0].(uint32)
			n.mu.Lock()
			conv, ok := n.convs[id]
			if sig.Name == "org.freedesktop.Notifications.NotificationClosed" {
				delete(n.convs, id)
				if n.last[conv] == id {
					delete(n.last, conv)
				}
			}
			n.mu.Unlock()
			if ok && sig.Name == "org.freedesktop.Notifications.ActionInvoked" {
				_ = exec.Command("qs", "ipc", "call", "phone", "openConversation", conv).Run()
			}
		}
	}()
	return n
}

func (n *notifier) message(conv, title, body string) {
	if n.conn == nil {
		return
	}
	n.mu.Lock()
	replaces := n.last[conv]
	n.mu.Unlock()
	obj := n.conn.Object("org.freedesktop.Notifications", "/org/freedesktop/Notifications")
	var id uint32
	err := obj.Call("org.freedesktop.Notifications.Notify", 0,
		"Messages", replaces, "phone", title, body,
		[]string{"default", "Open"},
		map[string]dbus.Variant{"category": dbus.MakeVariant("im.received")},
		int32(-1)).Store(&id)
	if err != nil {
		fmt.Fprintln(os.Stderr, "notify:", err)
		return
	}
	n.mu.Lock()
	n.convs[id] = conv
	n.last[conv] = id
	n.mu.Unlock()
}
