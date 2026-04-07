# 🛡️ Airgeddon Plugin: Manual Evil Twin Control

A highly customizable plugin for the WiFi auditing framework [airgeddon](https://github.com/v1s1t0r1sh3r3/airgeddon), giving you full manual control over the creation of Evil Twin Access Points.

With this plugin, before launching an Evil Twin (Captive Portal, Enterprise, WPA3 Downgrade), you will be interactively asked which **BSSID**, **channel**, and **ESSID** you want to use.

## ✨ Features

* **Manual Channel Selection:** Change the WiFi channel of the Evil Twin on-the-fly.
* **Manual BSSID Selection:** Choose between the exact original BSSID, an automatically spoofed one (airgeddon default), or enter a completely custom MAC address.
* **Manual ESSID Selection:** Keep the original network name, use the airgeddon default method (Zero-Width Space padding), or set a custom network name.
* **100% Compatible:** Hook-based design. It uses the official `prehook` and `posthook` methods of airgeddon and safely modifies the AP configuration files.
* **Multilingual:** Natively supports **all 13 languages** available in airgeddon (English, Spanish, French, German, Russian, etc.).

## 🎯 Why is this plugin useful? (Especially for WPA3)

By default, airgeddon copies the channel of the target network to set up the Evil Twin. **However, for some attacks—especially the WPA3 Downgrade attack—it is highly advantageous to broadcast the Evil Twin on a distant channel.**

* **Avoid Interference:** If the legitimate AP and your Evil Twin broadcast on the same or adjacent channels (e.g., Channel 1 and 2), the signals interfere with each other (Co-Channel Interference). 
* **Better Connection Rate:** By placing the Evil Twin on a completely interference-free channel far away from the original (e.g., Original on 1, Evil Twin on 11), your own signal becomes much clearer and stronger.
* **Deauth & Roaming:** After a successful deauthentication attack, disconnected devices (clients) scan for the strongest signal for their network. An interference-free, distant channel often forces the clients to roam and connect to your Evil Twin faster and more reliably.

## ⚙️ Installation

Simply put the .sh file in airgeddon's plugins folder.
