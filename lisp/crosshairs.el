<!DOCTYPE html>
<html lang="en">
<head>
    <title>Bot Check</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 600px;
            margin: 50px auto;
            padding: 20px;
        }

        .consent-box {
            border: 1px solid #ddd;
            padding: 30px;
            border-radius: 8px;
            background: #f9f9f9;
        }

        button {
            background: #007cba;
            color: white;
            padding: 12px 24px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 16px;
        }

        button:hover {
            background: #005a87;
        }

        form {
            display: flex;
            flex-direction: column;
            gap: 12px;
        }

        h1 {
            margin-top: 0;
        }

        small {
            text-align: right;
            display: block;
            margin-top: 40px;
            opacity: 0.7;
        }
    </style>
</head>
<body>
<div class="consent-box">
    <h1>Are you Human?</h1>
    <p>
        Silly question, but are you actually a human?
        I'm still having troubles with the mindless bots scraping the web in the service of AI companies,
        so be sure to press the right button.
    </p>

    <form action="/botcheck-confirm" method="post">
        <input type="hidden"/>
        <button type="submit">Yes, I'm a real person.</button>
    </form>

    <p>
      If you're using <tt>links2</tt> and you've clicked
      the button, reload using <tt>Ctrl+R</tt> and you
      should get redirected.
    </p>
    
    <noscript>
        <p>No JavaScript, relying on referrer header.</p>
    </noscript>

    <small>Powered by splitbrain's <a href="https://github.com/splitbrain/botcheck">botcheck</a>.</small>
</div>

<script>
    document.getElementsByTagName('form')[0].addEventListener('submit', (ev) => {
        ev.preventDefault();
        // Set cookie for 30 days
        const expires = new Date();
        expires.setTime(expires.getTime() + (30 * 24 * 60 * 60 * 1000));
        document.cookie = "botcheck=1; expires=" + expires.toUTCString() + "; path=/; SameSite=Lax";

        // Reload the page to continue with original request
        window.location.reload();
    });
</script>
</body>
</html>
