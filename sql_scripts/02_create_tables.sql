USE [test];
GO
CREATE TABLE [location] (
    [id] INT NOT NULL,
    [ts] DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL,
    [ts_end] DATETIME2 GENERATED ALWAYS AS ROW END HIDDEN NOT NULL,
    [name] NVARCHAR(128) NOT NULL,
    PERIOD FOR SYSTEM_TIME ([ts], [ts_end]),
    CONSTRAINT [pk_location] PRIMARY KEY CLUSTERED ([id])
)
WITH
(
    SYSTEM_VERSIONING = ON (HISTORY_TABLE = history.location_hist)
);
GO
CREATE TABLE [department] (
    [id] INT NOT NULL,
    [ts] DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL,
    [ts_end] DATETIME2 GENERATED ALWAYS AS ROW END HIDDEN NOT NULL,
    [name] NVARCHAR(128) NOT NULL,
    [loc_id] INTEGER NOT NULL,
    PERIOD FOR SYSTEM_TIME ([ts], [ts_end]),
    CONSTRAINT [pk_department] PRIMARY KEY CLUSTERED ([id]),
    CONSTRAINT [fk_department_location] FOREIGN KEY ([loc_id]) REFERENCES [location]([id])
)
WITH
(
    SYSTEM_VERSIONING = ON (HISTORY_TABLE = history.department_hist)
);
GO
CREATE TABLE [employee] (
    [id] INT NOT NULL,
    [ts] DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL,
    [ts_end] DATETIME2 GENERATED ALWAYS AS ROW END HIDDEN NOT NULL,
    [name] NVARCHAR(128) NOT NULL,
    [dep_id] INT NOT NULL,
    PERIOD FOR SYSTEM_TIME ([ts], [ts_end]),
    CONSTRAINT [pk_employee] PRIMARY KEY CLUSTERED ([id]),
    CONSTRAINT [fk_employee_department] FOREIGN KEY ([dep_id]) REFERENCES [department]([id])
)
WITH
(
    SYSTEM_VERSIONING = ON (HISTORY_TABLE = history.employee_hist)
);
GO
