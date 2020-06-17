from squad.ci import models as ci_m
from squad.core import models as m
from squad.ci.tasks import fetch

num_testjobs = 1
projects_slugs = {
    'android-lkft': [
        'mainline-gki-aosp-master-hikey960',
        'mainline-gki-aosp-master-db845c',
        '5.4-gki-aosp-master-hikey',
        '4.19-10.0-gsi-hikey',
        'android-hikey-linaro-4.14-aosp-premerge-ci',
        '4.9-10.0-gsi-hikey960',
        '4.9o-9.0-lcr-hikey',
        'android-hikey-linaro-4.4-android-8.1',
    ],
    'android-lkft-rc': [
        '5.4-gki-aosp-master-db845c',
        '4.19-q-10gsi-hikey960',
        '4.19-q-10gsi-hikey',
        '4.14-q-10gsi-hikey960',
        '4.14-q-10gsi-hikey',
        '4.9-p-10gsi-hikey960',
        '4.9-p-10gsi-hikey',
    ],
    'lkft': [
        'linux-stable-rc-5.7-oe',
        'linux-stable-rc-5.6-oe',
        'linux-stable-rc-5.5-oe',
        'linux-stable-rc-5.4-oe',
        'linux-stable-rc-4.19-oe',
        'linux-stable-rc-4.14-oe',
        'linux-stable-rc-4.9-oe',
    ]
}


job_ids = []
for group_slug in projects_slugs.keys():
    for slug in projects_slugs[group_slug]:
        p = m.Project.objects.filter(group__slug=group_slug, slug=slug).first()
        print('Working on %s' % p.full_name, flush=True)
        for tj in ci_m.TestJob.objects.filter(target=p, fetched=True).order_by('-created_at')[:num_testjobs]:
            print('Recreating testjob %s' % tj, flush=True)
            # Save data
            backend = tj.backend
            build = tj.target_build
            environment = tj.environment
            job_id = tj.job_id

            # Delete TestRun and TestJob (cascade delete)
            tj.testrun.delete()

            # Create fresh 
            new_tj = ci_m.TestJob.objects.create(
                backend=backend,
                target=p,
                target_build=build,
                environment=environment,
                submitted=True,
                job_id=job_id
            )

            job_ids.append(new_tj.id)

# Send all to queue
print('Send jobs to queue', flush=True)
for tj_id in job_ids:
    fetch.delay(tj_id)
