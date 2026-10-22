# Google Books API key

Google Books is a book search source in Mediabox. Search works without a key, but
Google throttles anonymous traffic to a small shared quota that everyone hits at
once. Adding your own key gives you a private quota (about 1000 requests per day),
which is plenty for browsing and adding books.

The key is optional. Skip this if you only search occasionally.

## Get a key

You make the key in the Google Cloud Console. It is free and does not need a
billing account.

1. Open the Google Cloud Console: https://console.cloud.google.com/
   On the first visit, pick a country and accept the Terms of Service, otherwise
   the console stays empty. You can skip any "start free trial" or card prompts.

2. Create a project (or pick one you already have). The project selector sits in
   the top blue bar, right of the "Google Cloud" logo. If you cannot find it, go
   straight to https://console.cloud.google.com/projectcreate, type a name, and
   press **Create**.

3. Enable the Books API. With your project selected, open
   https://console.cloud.google.com/apis/library/books.googleapis.com and press
   **Enable**.

4. Create the key. Go to **APIs & Services -> Credentials**
   (https://console.cloud.google.com/apis/credentials), press
   **+ Create credentials -> API key**, and copy the value (it starts with
   `AIza...`).

5. Restrict the key (recommended). On the key, open **Edit**, and under
   **API restrictions** choose **Restrict key -> Books API** so the key only
   works for books. For a desktop app you can leave **Application restrictions**
   set to **None**.

OAuth is not needed. It only covers a user's private bookshelves, which Mediabox
does not use.

## Add it to Mediabox

Paste the key into **Settings -> Credentials -> Google Books**, or into the
Google Books card during the first-run wizard. It is stored locally with your
other API keys and never committed to the project.

## Quota

The default is about 1000 requests per day per project, plus roughly one request
per second. You can raise it from a quota request in the Cloud Console if you ever
need more.
