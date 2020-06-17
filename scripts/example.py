import random
import os
from locust import HttpUser, task, between, TaskSet


class RudimentaryTaskset(TaskSet):

    def __init__(self, *args):
        self.lkft_project_list = []
        self.group_list = []
        self.project_list_dict = {}
        super().__init__(*args)

    def on_start(self):
        self.login()

    def login(self):
        # login to the application
        username = os.environ.get("SQUAD_USERNAME")
        password = os.environ.get("SQUAD_PASSWORD")
        response = self.client.get('/login/')
        csrftoken = response.cookies['csrftoken']
        login_request = self.client.post('/login/',
                {'username': username, 'password': password, 'next': '', 'csrfmiddlewaretoken': csrftoken},
                headers={'X-CSRFToken': csrftoken, 'Referer': self.parent.host + '/login/'})
        if login_request.status_code != 200:
            self.interrupt()
        lkft_project_list_request = self.client.get('/api/projects/?group__slug=lkft')
        if lkft_project_list_request.status_code == 200:
            for project in lkft_project_list_request.json()['results']:
                self.lkft_project_list.append(project['id'])
        group_list_request = self.client.get("/api/groups/")
        if group_list_request.status_code == 200:
            for group in group_list_request.json()['results']:
                group_slug = group['slug']
                self.group_list.append(group_slug)
                project_list_request = self.client.get(f"/api/projects/?group__slug={group_slug}")
                if project_list_request.status_code == 200:
                    project_list = project_list_request.json()['results']
                    if(project_list):
                        self.project_list_dict[group_slug] = [item['slug'] for item in project_list]

    @task
    def index_page(self):
        self.client.get("/")

    @task
    def view_latest_results(self):
        project_id_index = random.randint(0, len(self.lkft_project_list)-1)
        project_id = self.lkft_project_list[project_id_index]
        self.client.get(f"/api/projects/{project_id}/test_results/?limit=10&test_name=ltp-syscalls-tests%2Fsyslog07", name=f"/latest_results/{project_id}")

    @task(2)
    def view_project_list(self):
        if self.group_list:
            group_list_index = random.randint(0, len(self.group_list)-1)
            group_slug = self.group_list[group_list_index]
            self.client.get(f"/{group_slug}", name=f"/{group_slug}")

    def project_details_view(self, suffix):
        if self.group_list:
            group_list_index = random.randint(0, len(self.group_list)-1)
            group_slug = self.group_list[group_list_index]
            if group_slug in self.project_list_dict.keys():
                project_list_index = random.randint(0, len(self.project_list_dict[group_slug])-1)
                project_slug = self.project_list_dict[group_slug][project_list_index]
                self.client.get(f"/{group_slug}/{project_slug}/{suffix}", name=f"/{group_slug}/{project_slug}/{suffix}")

    @task(5)
    def view_build_list(self):
        self.project_details_view("")

    @task
    def view_project_metrics(self):
        self.project_details_view("metrics")

    @task
    def view_project_badge(self):
        self.project_details_view("badge")

    @task
    def view_project_builds(self):
        self.project_details_view("builds")


class QuickstartUser(HttpUser):
    wait_time = between(5, 9)
    tasks = {RudimentaryTaskset:2}


