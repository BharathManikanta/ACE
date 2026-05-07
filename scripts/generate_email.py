from jinja2 import Environment, FileSystemLoader
import os


def generate_email_content(args):

    template_dir = os.path.dirname(__file__)

    env = Environment(
        loader=FileSystemLoader(template_dir)
    )

    template = env.get_template(
        'email-template.jinja'
    )

    data = {
        'name': args.name,
        'service_name': args.service_name,
        'build_number': args.build_number,
        'build_time': args.build_time,

        # ADD THIS LINE
        'approval_url': os.getenv("APPROVAL_URL")
    }

    return template.render(data)
