````mermaid
stateDiagram-v2
    [*] --> ContainerCreated
    ContainerCreated --> ContainerRunning
    ContainerRunning --> AppInitializing
    AppInitializing --> AppReady

    note right of ContainerRunning
        Docker:
        Container is running
        Application may NOT be ready
    end note

    note right of AppReady
        Application:
        Health endpoint OK
        Service is usable
    end note
````
