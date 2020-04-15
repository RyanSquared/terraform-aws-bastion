resource "aws_s3_bucket" "ssh_public_keys" {
  bucket_prefix = "ssh-keys-"
  acl = "public-read"
  website {
    index_document = "index.html"
  }
}

resource "aws_s3_bucket_object" "ssh_public_keys" {
  bucket = "${aws_s3_bucket.ssh_public_keys.bucket}"
  key = "${
    replace(
      replace(
        sha256(
          base64decode(
            element(
              split(
                " ",
                file("${var.authorized_keys_directory}/${element(var.authorized_key_names,count.index)}.pub")
              ),
              "1"
            )
          )
        ),
        "=",
        ""
      ),
    "/\\/\\//",
    "\\//",
    )
  }"
  content = "${file("${var.authorized_keys_directory}/${element(var.authorized_key_names,count.index)}.pub")}"
  count = "${length(var.authorized_key_names)}"
  depends_on = ["aws_s3_bucket.ssh_public_keys"]
  acl = "public-read"
}
