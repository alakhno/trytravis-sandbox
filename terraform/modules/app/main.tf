data "template_file" "puma_service" {
  template = "${file("${path.module}/files/puma.service.tpl")}"

  vars = {
    database_url = "${var.database_url}"
  }
}

resource "google_compute_instance" "app" {
  name         = "reddit-app-${var.env}"
  machine_type = "g1-small"
  zone         = "${var.zone}"
  tags         = ["reddit-app-${var.env}"]

  boot_disk {
    initialize_params {
      image = "${var.app_disk_image}"
    }
  }

  network_interface {
    network = "default"

    access_config {
      nat_ip = "${google_compute_address.app_ip.address}"
    }
  }

  metadata {
    ssh-keys = "appuser:${file(var.public_key_path)}"
  }
}

resource "null_resource" "app_deploy" {
  count = "${var.app_deploy ? 1 : 0}"
  triggers = {
    app_instance_id = "google_compute_instance.app.id"
  }

  connection {
    host  = "${google_compute_instance.app.network_interface.0.access_config.0.nat_ip}"
    type  = "ssh"
    user  = "appuser"
    agent = false

    private_key = "${file(var.private_key_path)}"
  }

  provisioner "file" {
    content     = "${data.template_file.puma_service.rendered}"
    destination = "/tmp/puma.service"
  }

  provisioner "file" {
    source      = "${path.module}/files/deploy.sh"
    destination = "/tmp/deploy.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sh /tmp/deploy.sh",
    ]
  }
}

resource "google_compute_address" "app_ip" {
  name = "reddit-app-ip-${var.env}"
}

resource "google_compute_firewall" "firewall_puma" {
  name    = "allow-puma-${var.env}"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["9292", "80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["reddit-app-${var.env}"]
}
