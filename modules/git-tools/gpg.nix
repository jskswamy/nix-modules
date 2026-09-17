_: {
  enable = true;
  settings = {
    # Privacy & UI
    no-greeting = true;
    no-comments = true;
    no-emit-version = true;
    armor = true;
    throw-keyids = true;

    # Strong cryptography preferences
    personal-cipher-preferences = "AES256 AES192 AES";
    personal-digest-preferences = "SHA512 SHA384 SHA256";
    personal-compress-preferences = "ZLIB BZIP2 ZIP Uncompressed";
    default-preference-list = "SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed";

    # Strong algorithms for key operations
    cert-digest-algo = "SHA512";
    s2k-digest-algo = "SHA512";
    s2k-cipher-algo = "AES256";

    # Security and validation
    require-cross-certification = true;
    with-fingerprint = true;
    keyid-format = "0xlong";
    list-options = "show-uid-validity";
    verify-options = "show-uid-validity";

    # Compatibility
    charset = "utf-8";
    use-agent = true;

    # Memory protection (comment out if it causes issues)
    require-secmem = true;
    no-symkey-cache = true;
  };
}
