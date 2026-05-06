import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
import argparse
import os

from generate_email import generate_email_content


def send_email(subject, html_content, recipient):

    smtp_server = os.getenv("SMTP_SERVER", "smtp.gmail.com")
    smtp_port = int(os.getenv("SMTP_PORT", "587"))

    smtp_username = os.getenv("SMTP_USERNAME")
    smtp_password = os.getenv("SMTP_PASSWORD")

    print(f"Using SMTP Server: {smtp_server}:{smtp_port}")

    msg = MIMEMultipart('alternative')

    msg['Subject'] = subject
    msg['From'] = smtp_username
    msg['To'] = recipient

    part = MIMEText(html_content, 'html')
    msg.attach(part)

    try:

        with smtplib.SMTP(
            smtp_server,
            smtp_port
        ) as server:

            # Enable TLS
            server.starttls()

            # Login
            server.login(
                smtp_username,
                smtp_password
            )

            # Send Email
            server.sendmail(
                msg['From'],
                recipient.split(','),
                msg.as_string()
            )

            print("✅ Email sent successfully")

    except Exception as e:
        print("❌ Failed to send email:", str(e))
        raise


if __name__ == '__main__':

    parser = argparse.ArgumentParser(
        description='Generate and send email.'
    )

    parser.add_argument('--name', required=True)
    parser.add_argument('--status', required=True)
    parser.add_argument('--service_name', required=True)
    parser.add_argument('--build_number', required=True)
    parser.add_argument('--build_time', required=True)
    parser.add_argument('--recipient', required=True)

    args = parser.parse_args()

    clean_service_name = (
        args.service_name
        .replace('\n', ', ')
        .replace('\r', '')
        .strip()
    )

    args.service_name = clean_service_name

    html_content = generate_email_content(args)

    subject = (
        f'{clean_service_name} '
        f'CP4I Job Notification - '
        f'{args.status}'
    )

    send_email(
        subject,
        html_content,
        args.recipient
    )
